import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/diagnostic_log.dart';
import '../core/secure_session.dart';
import '../core/wire.dart';
import '../platform/windows_input.dart';
import 'host_dashboard.dart';

class PairedClient {
  const PairedClient({
    required this.id,
    required this.name,
    required this.connected,
  });

  final String id;
  final String name;
  final bool connected;
}

class PendingPairingRequest {
  const PendingPairingRequest({
    required this.id,
    required this.clientName,
    required this.address,
  });

  final String id;
  final String clientName;
  final String address;
}

class _PendingPairingRequestState {
  const _PendingPairingRequestState({
    required this.request,
    required this.decision,
  });

  final PendingPairingRequest request;
  final Completer<bool> decision;
}

class RemoteHostService extends ChangeNotifier {
  RemoteHostService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage() {
    _dashboard = HostDashboardServer(
      stateProvider: _dashboardState,
      actionHandler: _handleDashboardAction,
      pairingQrProvider: () => pairingQrPayload,
    );
  }

  static const int port = 47652;
  static const _privateKeyStorageKey = 'orc.host.signing-private.v1';
  static const _clientsStorageKey = 'orc.host.clients.v1';

  final FlutterSecureStorage _storage;
  final Ed25519 _signatures = Ed25519();
  final X25519 _keyExchange = X25519();
  late final HostDashboardServer _dashboard;
  final Map<String, _HostClientRecord> _clients = {};
  final Map<String, _PendingPairingRequestState> _pendingPairingRequests = {};
  final Map<String, Set<WebSocket>> _clientSockets = {};
  final Set<WebSocket> _webSockets = {};
  final Set<String> _connectedClients = {};

  HttpServer? _server;
  StreamSubscription<HttpRequest>? _serverSubscription;
  RawDatagramSocket? _discoverySocket;
  StreamSubscription<RawSocketEvent>? _discoverySubscription;
  SimpleKeyPair? _signingKey;
  Uint8List? _signingPublicKeyBytes;
  String? _serverId;
  String? _pairingToken;
  DateTime? _pairingExpiresAt;
  List<String> _localAddresses = const [];
  String? _lastError;
  String? _lastConnectionAddress;
  DateTime? _lastConnectionAt;
  bool _disposed = false;

  bool get isRunning => _server != null;
  String? get lastError => _lastError;
  String? get dashboardUrl => _dashboard.url;
  int? get dashboardPort => _dashboard.port;
  List<String> get localAddresses => List.unmodifiable(_localAddresses);
  List<PendingPairingRequest> get pendingPairingRequests =>
      _pendingPairingRequests.values
          .map((pending) => pending.request)
          .toList(growable: false);
  DateTime? get pairingExpiresAt => _pairingExpiresAt;
  String? get pairingQrPayload {
    final token = _pairingToken;
    final expiresAt = _pairingExpiresAt;
    final serverId = _serverId;
    if (_server == null ||
        token == null ||
        expiresAt == null ||
        serverId == null ||
        _signingPublicKeyBytes == null ||
        DateTime.now().isAfter(expiresAt)) {
      return null;
    }
    return jsonEncode({
      'type': 'open-remote-pairing',
      'version': 1,
      'serverId': serverId,
      'addresses': _localAddresses,
      'port': port,
      'signingPublicKey': encodeBytes(_signingPublicKeyBytes!),
      'pairingToken': token,
      'expiresAt': expiresAt.millisecondsSinceEpoch,
    });
  }

  List<PairedClient> get clients => _clients.values
      .map(
        (client) => PairedClient(
          id: client.id,
          name: client.name,
          connected: _connectedClients.contains(client.id),
        ),
      )
      .toList(growable: false);

  Future<void> startDashboard() => _dashboard.start();

  Future<void> stopDashboard() => _dashboard.stop();

  Map<String, Object?> _dashboardState() => {
    'running': isRunning,
    'error': _lastError,
    'addresses': _localAddresses,
    'port': port,
    'discoveryPort': localDiscoveryPort,
    'discoveryRunning': _discoverySocket != null,
    'dashboardPort': dashboardPort,
    'pairingQrAvailable': pairingQrPayload != null,
    'pairingExpiresAt': _pairingExpiresAt?.toIso8601String(),
    'logPath': DiagnosticLog.filePath,
    'lastConnectionAddress': _lastConnectionAddress,
    'lastConnectionAt': _lastConnectionAt?.toIso8601String(),
    'requests': pendingPairingRequests
        .map(
          (request) => {
            'id': request.id,
            'name': request.clientName,
            'address': request.address,
          },
        )
        .toList(growable: false),
    'clients': clients
        .map(
          (client) => {
            'id': client.id,
            'name': client.name,
            'connected': client.connected,
          },
        )
        .toList(growable: false),
  };

  Future<void> _handleDashboardAction(
    String action,
    Map<String, dynamic> parameters,
  ) async {
    switch (action) {
      case 'start':
        await start();
        return;
      case 'stop':
        await stop();
        return;
      case 'approve':
      case 'reject':
        final requestId = parameters['id'];
        if (requestId is! String || requestId.length > 64) {
          throw const FormatException('Pedido de conexão inválido.');
        }
        await decidePairingRequest(requestId, approve: action == 'approve');
        return;
      case 'revoke':
        final clientId = parameters['id'];
        if (clientId is! String || clientId.length > 64) {
          throw const FormatException('Celular pareado inválido.');
        }
        await revokeClient(clientId);
        return;
      case 'new_pairing_code':
        await createPairingCode();
        return;
      default:
        throw const FormatException('Ação desconhecida no painel local.');
    }
  }

  Future<void> start() async {
    if (_server != null) return;
    _lastError = null;
    await DiagnosticLog.record(
      'Windows',
      'Iniciando servidor TCP $port e descoberta UDP $localDiscoveryPort.',
    );
    try {
      _signingKey = await _loadOrCreateSigningKey();
      _signingPublicKeyBytes = publicKeyBytes(
        await _signingKey!.extractPublicKey(),
      );
      _serverId = encodeBytes(
        (await Sha256().hash(_signingPublicKeyBytes!)).bytes,
      ).substring(0, 22);
      await _loadClients();
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      _localAddresses =
          interfaces
              .expand((interface) => interface.addresses)
              .map((address) => address.address)
              .where(isPrivateIpv4)
              .toSet()
              .toList()
            ..sort();
      await DiagnosticLog.record(
        'Windows',
        'Interfaces IPv4 locais: ${_localAddresses.join(', ')}.',
      );
      if (_localAddresses.isEmpty) {
        throw StateError('Nenhum endereço IPv4 privado foi encontrado.');
      }
      final server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        port,
        shared: true,
      );
      _server = server;
      _serverSubscription = server.listen(
        (request) => unawaited(_handleRequest(request)),
        onError: (Object error) {
          _lastError = 'Falha no servidor local: $error';
          _notifyListeners();
        },
      );
      await DiagnosticLog.record(
        'Windows',
        'Servidor TCP ouvindo em 0.0.0.0:$port.',
      );
      final discoverySocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        localDiscoveryPort,
        reuseAddress: true,
      );
      _discoverySocket = discoverySocket;
      _discoverySubscription = discoverySocket.listen(
        _handleDiscoveryEvent,
        onError: (Object error) {
          _lastError = 'Falha na descoberta pela rede local: $error';
          _notifyListeners();
        },
      );
      await DiagnosticLog.record(
        'Windows',
        'Descoberta UDP ouvindo em 0.0.0.0:$localDiscoveryPort.',
      );
      await createPairingCode();
      _notifyListeners();
    } catch (error, stackTrace) {
      _lastError = error is SocketException && error.osError?.errorCode == 10048
          ? 'A porta local $port já está em uso.'
          : error.toString();
      await DiagnosticLog.record(
        'Windows',
        'Falha ao iniciar servidor.',
        error: error,
        stackTrace: stackTrace,
      );
      await stop();
      _notifyListeners();
      rethrow;
    }
  }

  Future<void> stop() async {
    _pairingToken = null;
    _pairingExpiresAt = null;
    for (final pending in _pendingPairingRequests.values) {
      if (!pending.decision.isCompleted) pending.decision.complete(false);
    }
    final subscription = _serverSubscription;
    _serverSubscription = null;
    await subscription?.cancel();
    final discoverySubscription = _discoverySubscription;
    _discoverySubscription = null;
    await discoverySubscription?.cancel();
    _discoverySocket?.close();
    _discoverySocket = null;
    final server = _server;
    _server = null;
    await Future.wait(
      _webSockets.map((socket) => socket.close(WebSocketStatus.goingAway)),
    );
    _webSockets.clear();
    await server?.close(force: true);
    _connectedClients.clear();
    _notifyListeners();
  }

  void _handleDiscoveryEvent(RawSocketEvent event) {
    final socket = _discoverySocket;
    if (socket == null || event != RawSocketEvent.read) return;
    Datagram? datagram;
    while ((datagram = socket.receive()) != null) {
      try {
        final packet = datagram!;
        if (packet.data.length > 512 ||
            !isPrivateIpv4(packet.address.address)) {
          continue;
        }
        final decoded = jsonDecode(utf8.decode(packet.data));
        if (decoded is! Map<String, dynamic> ||
            decoded['type'] != 'open-remote-discover' ||
            decoded['version'] != 1 ||
            decoded['nonce'] is! String ||
            _serverId == null ||
            _signingPublicKeyBytes == null) {
          continue;
        }
        final response = jsonEncode({
          'type': 'open-remote-server',
          'version': 1,
          'nonce': decoded['nonce'],
          'serverId': _serverId,
          'name': _cleanServerName(Platform.localHostname),
          'addresses': _localAddresses,
          'port': port,
          'signingPublicKey': encodeBytes(_signingPublicKeyBytes!),
        });
        socket.send(utf8.encode(response), packet.address, packet.port);
      } catch (_) {
        // Ignore malformed discovery packets on the local network.
      }
    }
  }

  Future<void> createPairingCode() async {
    if (_server == null) return;
    _pairingToken = encodeBytes(secureRandomBytes(32));
    _pairingExpiresAt = DateTime.now().add(const Duration(minutes: 5));
    _notifyListeners();
  }

  Future<void> revokeClient(String clientId) async {
    _clients.remove(clientId);
    final sockets = _clientSockets.remove(clientId) ?? <WebSocket>{};
    _connectedClients.remove(clientId);
    await _saveClients();
    await Future.wait(
      sockets.map((socket) => socket.close(WebSocketStatus.policyViolation)),
    );
    _notifyListeners();
  }

  Future<SimpleKeyPair> _loadOrCreateSigningKey() async {
    final storedSeed = await _storage.read(key: _privateKeyStorageKey);
    final seed = storedSeed == null
        ? secureRandomBytes(32)
        : decodeBytes(storedSeed, exactLength: 32);
    if (storedSeed == null) {
      await _storage.write(
        key: _privateKeyStorageKey,
        value: encodeBytes(seed),
      );
    }
    return _signatures.newKeyPairFromSeed(seed);
  }

  Future<void> _loadClients() async {
    _clients.clear();
    final stored = await _storage.read(key: _clientsStorageKey);
    if (stored == null) return;
    final decoded = jsonDecode(stored);
    if (decoded is! List) return;
    for (final row in decoded) {
      if (row is! Map<String, dynamic> ||
          row['id'] is! String ||
          row['name'] is! String ||
          row['tokenHash'] is! String) {
        continue;
      }
      final record = _HostClientRecord(
        id: row['id'] as String,
        name: row['name'] as String,
        tokenHash: row['tokenHash'] as String,
      );
      _clients[record.id] = record;
    }
  }

  Future<void> _saveClients() async {
    final records = _clients.values
        .map(
          (client) => {
            'id': client.id,
            'name': client.name,
            'tokenHash': client.tokenHash,
          },
        )
        .toList(growable: false);
    await _storage.write(key: _clientsStorageKey, value: jsonEncode(records));
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final remoteAddress = request.connectionInfo?.remoteAddress.address;
    if (request.uri.path == '/info' && request.method == 'GET') {
      if (remoteAddress == null || !isPrivateIpv4(remoteAddress)) {
        request.response.statusCode = HttpStatus.forbidden;
        await request.response.close();
        return;
      }
      final publicKey = _signingPublicKeyBytes;
      final serverId = _serverId;
      if (publicKey == null || serverId == null) {
        request.response.statusCode = HttpStatus.serviceUnavailable;
        await request.response.close();
        return;
      }
      request.response.headers.contentType = ContentType.json;
      request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      request.response.write(
        jsonEncode({
          'type': 'open-remote-server',
          'version': 1,
          'serverId': serverId,
          'name': _cleanServerName(Platform.localHostname),
          'addresses': _localAddresses,
          'port': port,
          'signingPublicKey': encodeBytes(publicKey),
        }),
      );
      await request.response.close();
      await DiagnosticLog.record(
        'Windows',
        'Enviado /info para $remoteAddress.',
      );
      return;
    }
    if (request.uri.path != '/control' || request.method != 'GET') {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    if (remoteAddress == null || !isPrivateIpv4(remoteAddress)) {
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
      return;
    }
    try {
      await DiagnosticLog.record(
        'Windows',
        'Conexão TCP/WebSocket recebida de $remoteAddress.',
      );
      _lastConnectionAddress = remoteAddress;
      _lastConnectionAt = DateTime.now();
      _notifyListeners();
      final socket = await WebSocketTransformer.upgrade(request);
      _webSockets.add(socket);
      socket.pingInterval = const Duration(seconds: 25);
      try {
        await _handleSocket(socket, remoteAddress: remoteAddress);
      } finally {
        _webSockets.remove(socket);
      }
    } catch (error, stackTrace) {
      _lastError = 'Conexão local recusada: $error';
      await DiagnosticLog.record(
        'Windows',
        'Falha processando conexão de $remoteAddress.',
        error: error,
        stackTrace: stackTrace,
      );
      _notifyListeners();
    }
  }

  Future<void> _handleSocket(
    WebSocket socket, {
    required String remoteAddress,
  }) async {
    String? authenticatedClientId;
    var phase = 'handshake';
    final heldMouseButtons = <String>{};
    final heldModifiers = <String>{};
    final iterator = StreamIterator<Object?>(socket);
    try {
      final hello = await _nextMap(iterator);
      if (hello['type'] != 'hello' ||
          hello['version'] != 1 ||
          hello['clientPublicKey'] is! String ||
          hello['clientNonce'] is! String) {
        throw const FormatException('Handshake inválido.');
      }
      final clientPublicBytes = decodeBytes(
        hello['clientPublicKey'],
        exactLength: 32,
      );
      final clientNonce = decodeBytes(hello['clientNonce'], exactLength: 16);
      final clientPublicKey = SimplePublicKey(
        clientPublicBytes,
        type: KeyPairType.x25519,
      );
      final serverEphemeralKey = await _keyExchange.newKeyPair();
      final serverEphemeralPublic = publicKeyBytes(
        await serverEphemeralKey.extractPublicKey(),
      );
      final serverNonce = secureRandomBytes(16);
      final transcript = _handshakeTranscript(
        clientPublicBytes,
        serverEphemeralPublic,
        clientNonce,
        serverNonce,
      );
      final signature = await _signatures.sign(
        transcript,
        keyPair: _signingKey!,
      );
      socket.add(
        jsonEncode({
          'type': 'server_key',
          'version': 1,
          'serverEphemeralKey': encodeBytes(serverEphemeralPublic),
          'serverNonce': encodeBytes(serverNonce),
          'signature': encodeBytes(signature.bytes),
        }),
      );

      phase = 'desafio seguro';
      final sharedSecret = await _keyExchange.sharedSecretKey(
        keyPair: serverEphemeralKey,
        remotePublicKey: clientPublicKey,
      );
      final session = await SecureSession.derive(
        sharedSecret: sharedSecret,
        clientNonce: clientNonce,
        serverNonce: serverNonce,
        isServer: true,
      );
      socket.add(
        jsonEncode(
          await session.encrypt({
            'kind': 'challenge',
            'nonce': encodeBytes(secureRandomBytes(24)),
          }),
        ),
      );

      phase = 'resposta do celular';
      final encryptedAuth = await _nextMap(iterator);
      final auth = await session.decrypt(encryptedAuth);
      phase = 'autorização';
      late final _AuthorizedClient paired;
      try {
        paired = await _authorize(auth, remoteAddress: remoteAddress);
      } catch (_) {
        socket.add(
          jsonEncode(
            await session.encrypt({'kind': 'auth_error', 'mode': auth['mode']}),
          ),
        );
        rethrow;
      }
      authenticatedClientId = paired.clientId;
      _lastError = null;
      await DiagnosticLog.record(
        'Windows',
        'Cliente autorizado (${paired.clientId}) em $remoteAddress.',
      );
      _clientSockets
          .putIfAbsent(paired.clientId, () => <WebSocket>{})
          .add(socket);
      _connectedClients.add(paired.clientId);
      _notifyListeners();
      socket.add(
        jsonEncode(
          await session.encrypt({
            'kind': 'auth_ok',
            'clientId': paired.clientId,
            'clientToken': paired.clientToken,
            'serverId': _serverId,
          }),
        ),
      );

      phase = 'comandos';
      while (await iterator.moveNext()) {
        final frame = iterator.current;
        final command = await session.decrypt(frame);
        await _applyCommand(command, heldMouseButtons, heldModifiers);
      }
    } catch (error, stackTrace) {
      await DiagnosticLog.record(
        'Windows',
        'Conexão de $remoteAddress encerrada durante $phase.',
        error: error,
        stackTrace: stackTrace,
      );
      _lastError = 'Falha com $remoteAddress durante $phase: $error';
      _notifyListeners();
    } finally {
      for (final button in heldMouseButtons.toList()) {
        try {
          await WindowsInput.mouseButton(button, false);
        } catch (_) {}
      }
      for (final modifier in heldModifiers.toList()) {
        try {
          await WindowsInput.keyState(modifier, false);
        } catch (_) {}
      }
      if (authenticatedClientId != null) {
        final sockets = _clientSockets[authenticatedClientId];
        sockets?.remove(socket);
        if (sockets == null || sockets.isEmpty) {
          _clientSockets.remove(authenticatedClientId);
          _connectedClients.remove(authenticatedClientId);
        }
        _notifyListeners();
      }
      await iterator.cancel();
      await socket.close(WebSocketStatus.normalClosure);
    }
  }

  Future<_AuthorizedClient> _authorize(
    Map<String, dynamic> auth, {
    required String remoteAddress,
  }) async {
    if (auth['kind'] != 'auth') {
      throw const FormatException('Autorização inválida.');
    }
    if (auth['mode'] == 'pair') {
      final token = _pairingToken;
      final expires = _pairingExpiresAt;
      final suppliedToken = auth['pairingToken'];
      if (token == null ||
          expires == null ||
          DateTime.now().isAfter(expires) ||
          suppliedToken != token) {
        throw const FormatException('Pareamento expirado ou inválido.');
      }
      if (_clients.length >= 32) {
        throw const FormatException('Limite de celulares pareados atingido.');
      }
      final paired = await _registerClient(
        _cleanClientName(auth['clientName']),
      );
      await createPairingCode();
      return paired;
    }
    if (auth['mode'] == 'request_pair') {
      if (_clients.length >= 32) {
        throw const FormatException('Limite de celulares pareados atingido.');
      }
      if (_pendingPairingRequests.length >= 4) {
        throw const FormatException(
          'Ha pedidos de pareamento aguardando aprovacao.',
        );
      }
      final requestId = encodeBytes(secureRandomBytes(12));
      final pending = _PendingPairingRequestState(
        request: PendingPairingRequest(
          id: requestId,
          clientName: _cleanClientName(auth['clientName']),
          address: remoteAddress,
        ),
        decision: Completer<bool>(),
      );
      _pendingPairingRequests[requestId] = pending;
      _notifyListeners();
      bool approved;
      try {
        approved = await pending.decision.future.timeout(
          const Duration(seconds: 90),
          onTimeout: () => false,
        );
      } finally {
        _pendingPairingRequests.remove(requestId);
        _notifyListeners();
      }
      if (!approved) {
        throw const FormatException('Pareamento recusado no Windows.');
      }
      return _registerClient(pending.request.clientName);
    }
    if (auth['mode'] == 'resume') {
      final id = auth['clientId'];
      final token = auth['clientToken'];
      if (id is! String || token is! String || token.length > 128) {
        throw const FormatException('Credencial inválida.');
      }
      final client = _clients[id];
      if (client == null || client.tokenHash != await _tokenHash(token)) {
        throw const FormatException('Este dispositivo não está autorizado.');
      }
      return _AuthorizedClient(clientId: id, clientToken: token);
    }
    throw const FormatException('Modo de autorização inválido.');
  }

  Future<_AuthorizedClient> _registerClient(String name) async {
    final id = encodeBytes(secureRandomBytes(16));
    final clientToken = encodeBytes(secureRandomBytes(32));
    _clients[id] = _HostClientRecord(
      id: id,
      name: name,
      tokenHash: await _tokenHash(clientToken),
    );
    await _saveClients();
    return _AuthorizedClient(clientId: id, clientToken: clientToken);
  }

  Future<void> decidePairingRequest(
    String requestId, {
    required bool approve,
  }) async {
    final pending = _pendingPairingRequests[requestId];
    if (pending == null || pending.decision.isCompleted) return;
    pending.decision.complete(approve);
    await DiagnosticLog.record(
      'Windows',
      'Pedido de ${pending.request.clientName} (${pending.request.address}) ${approve ? 'aprovado' : 'recusado'}.',
    );
    _notifyListeners();
  }

  Future<void> _applyCommand(
    Map<String, dynamic> command,
    Set<String> heldMouseButtons,
    Set<String> heldModifiers,
  ) async {
    final kind = command['kind'];
    switch (kind) {
      case 'mouse.move':
        final dx = _boundedNumber(command['dx'], -500, 500);
        final dy = _boundedNumber(command['dy'], -500, 500);
        await WindowsInput.moveMouse(dx, dy);
        return;
      case 'mouse.button':
        final button = command['button'];
        final pressed = command['pressed'];
        if (button is! String ||
            !const {'left', 'right', 'middle'}.contains(button) ||
            pressed is! bool) {
          throw const FormatException('Botão de mouse inválido.');
        }
        await WindowsInput.mouseButton(button, pressed);
        if (pressed) {
          heldMouseButtons.add(button);
        } else {
          heldMouseButtons.remove(button);
        }
        return;
      case 'mouse.scroll':
        final delta = _boundedNumber(command['delta'], -1200, 1200).round();
        await WindowsInput.scroll(delta);
        return;
      case 'keyboard.text':
        final text = command['text'];
        if (text is! String || text.length > 512) {
          throw const FormatException('Texto inválido.');
        }
        await WindowsInput.typeText(text);
        return;
      case 'keyboard.key':
        final key = command['key'];
        if (key is! String ||
            (!_allowedKeys.contains(key) &&
                !RegExp(r'^(?:[a-z0-9]|f(?:[1-9]|1[0-2]))$').hasMatch(key))) {
          throw const FormatException('Tecla não permitida.');
        }
        await WindowsInput.pressKey(key);
        return;
      case 'keyboard.modifier':
        final key = command['key'];
        final pressed = command['pressed'];
        if (key is! String ||
            !_allowedModifiers.contains(key) ||
            pressed is! bool) {
          throw const FormatException('Modificador de teclado inválido.');
        }
        await WindowsInput.keyState(key, pressed);
        if (pressed) {
          heldModifiers.add(key);
        } else {
          heldModifiers.remove(key);
        }
        return;
      case 'media.command':
        final action = command['action'];
        if (action is! String || !_allowedMedia.contains(action)) {
          throw const FormatException('Comando de mídia não permitido.');
        }
        await WindowsInput.media(action);
        return;
      default:
        throw const FormatException('Comando desconhecido.');
    }
  }

  static double _boundedNumber(Object? value, double min, double max) {
    if (value is! num || !value.isFinite || value < min || value > max) {
      throw const FormatException('Valor fora dos limites.');
    }
    return value.toDouble();
  }

  static String _cleanClientName(Object? value) {
    if (value is! String || value.trim().isEmpty) return 'Android';
    final clean = value.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
    if (clean.isEmpty) return 'Android';
    return clean.substring(0, clean.length.clamp(1, 32).toInt());
  }

  static String _cleanServerName(String value) {
    final clean = value.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
    if (clean.isEmpty) return 'Open Remote';
    return clean.substring(0, clean.length.clamp(1, 64).toInt());
  }

  Future<Map<String, dynamic>> _nextMap(
    StreamIterator<Object?> iterator,
  ) async {
    if (!await iterator.moveNext().timeout(const Duration(seconds: 12))) {
      throw SocketException('A sessão foi encerrada.');
    }
    final frame = iterator.current;
    if (frame is! String || frame.length > SecureSession.maxFrameBytes * 2) {
      throw const FormatException('Quadro de rede inválido.');
    }
    final decoded = jsonDecode(frame);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Quadro JSON inválido.');
    }
    return decoded;
  }

  static List<int> _handshakeTranscript(
    List<int> clientPublic,
    List<int> serverPublic,
    List<int> clientNonce,
    List<int> serverNonce,
  ) => utf8.encode(
    [
      'open-remote/v1/handshake',
      encodeBytes(clientPublic),
      encodeBytes(serverPublic),
      encodeBytes(clientNonce),
      encodeBytes(serverNonce),
    ].join('\n'),
  );

  static Future<String> _tokenHash(String token) async =>
      encodeBytes((await Sha256().hash(utf8.encode(token))).bytes);

  static const _allowedKeys = {
    'enter',
    'backspace',
    'tab',
    'escape',
    'space',
    'arrowUp',
    'arrowDown',
    'arrowLeft',
    'arrowRight',
    'delete',
  };
  static const _allowedMedia = {
    'volumeUp',
    'volumeDown',
    'volumeMute',
    'playPause',
    'nextTrack',
    'previousTrack',
  };
  static const _allowedModifiers = {'control', 'alt', 'shift'};

  void _notifyListeners() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stop());
    unawaited(stopDashboard());
    super.dispose();
  }
}

class _HostClientRecord {
  const _HostClientRecord({
    required this.id,
    required this.name,
    required this.tokenHash,
  });

  final String id;
  final String name;
  final String tokenHash;
}

class _AuthorizedClient {
  const _AuthorizedClient({required this.clientId, required this.clientToken});

  final String clientId;
  final String clientToken;
}
