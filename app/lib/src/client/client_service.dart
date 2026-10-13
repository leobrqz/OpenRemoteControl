import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/diagnostic_log.dart';
import '../core/secure_session.dart';
import '../core/wire.dart';

class SavedHost {
  const SavedHost({
    required this.serverId,
    required this.name,
    required this.addresses,
    required this.port,
    required this.signingPublicKey,
  });

  final String serverId;
  final String name;
  final List<String> addresses;
  final int port;
  final String signingPublicKey;
}

class RemoteClientService extends ChangeNotifier {
  RemoteClientService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _hostsStorageKey = 'orc.client.hosts.v1';
  static const _manualEndpointStorageKey = 'orc.client.manual-endpoint.v1';
  final FlutterSecureStorage _storage;
  final X25519 _keyExchange = X25519();
  final Ed25519 _signatures = Ed25519();

  WebSocket? _socket;
  StreamIterator<Object?>? _iterator;
  SecureSession? _session;
  Future<void> _sendQueue = Future<void>.value();
  bool _isConnecting = false;
  bool _isResolvingManual = false;
  bool _isDiscovering = false;
  String? _connectedServerId;
  String? _connectedAddress;
  String? _lastError;
  List<DiscoveredHost> _discoveredHosts = const [];
  bool _disposed = false;

  bool get isConnected => _socket != null;
  bool get isConnecting => _isConnecting || _isResolvingManual;
  bool get isDiscovering => _isDiscovering;
  List<DiscoveredHost> get discoveredHosts => _discoveredHosts;
  String? get connectedAddress => _connectedAddress;
  String? get lastError => _lastError;

  Future<List<DiscoveredHost>> discoverHosts() async {
    if (_isDiscovering) return _discoveredHosts;
    _isDiscovering = true;
    _notifyListeners();
    await DiagnosticLog.record(
      'Android',
      'Iniciando descoberta UDP em 255.255.255.255:$localDiscoveryPort.',
    );
    RawDatagramSocket? socket;
    StreamSubscription<RawSocketEvent>? subscription;
    try {
      await _ensureLocalNetworkPermission();
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      final packets = <Datagram>[];
      subscription = socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        Datagram? packet;
        while ((packet = socket!.receive()) != null) {
          if (packet!.data.length <= 4096) packets.add(packet!);
        }
      });
      final nonce = encodeBytes(secureRandomBytes(16));
      final query = utf8.encode(
        jsonEncode({
          'type': 'open-remote-discover',
          'version': 1,
          'nonce': nonce,
        }),
      );
      final broadcastAddress = InternetAddress('255.255.255.255');
      for (var attempt = 0; attempt < 3; attempt++) {
        socket.send(query, broadcastAddress, localDiscoveryPort);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      await subscription.cancel();
      subscription = null;
      socket.close();
      socket = null;

      final hosts = <String, DiscoveredHost>{};
      for (final packet in packets) {
        final host = await _parseDiscoveredHost(packet, nonce);
        if (host != null) hosts[host.serverId] = host;
      }
      _discoveredHosts = hosts.values.toList(growable: false)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      await DiagnosticLog.record(
        'Android',
        'Descoberta concluída: ${_discoveredHosts.length} servidor(es) encontrados.',
      );
      return _discoveredHosts;
    } catch (error, stackTrace) {
      await DiagnosticLog.record(
        'Android',
        'Falha durante descoberta da rede local.',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    } finally {
      await subscription?.cancel();
      socket?.close();
      _isDiscovering = false;
      _notifyListeners();
    }
  }

  Future<DiscoveredHost?> _parseDiscoveredHost(
    Datagram packet,
    String nonce,
  ) async {
    if (!isPrivateIpv4(packet.address.address)) return null;
    try {
      final decoded = jsonDecode(utf8.decode(packet.data));
      if (decoded is! Map<String, dynamic> ||
          decoded['type'] != 'open-remote-server' ||
          decoded['version'] != 1 ||
          decoded['nonce'] != nonce) {
        return null;
      }
      return _hostFromDescriptor(
        decoded,
        sourceAddress: packet.address.address,
      );
    } on FormatException {
      return null;
    }
  }

  Future<DiscoveredHost?> _hostFromDescriptor(
    Map<String, dynamic> decoded, {
    required String sourceAddress,
  }) async {
    final serverId = decoded['serverId'];
    final rawName = decoded['name'];
    final rawAddresses = decoded['addresses'];
    final port = decoded['port'];
    final publicKey = decoded['signingPublicKey'];
    if (serverId is! String ||
        serverId.length > 64 ||
        rawName is! String ||
        rawName.trim().isEmpty ||
        rawName.length > 64 ||
        rawAddresses is! List ||
        rawAddresses.length > 16 ||
        rawAddresses.any(
          (address) => address is! String || !isPrivateIpv4(address),
        ) ||
        port is! int ||
        port < 1024 ||
        port > 65535) {
      return null;
    }
    final publicKeyBytes = decodeBytes(publicKey, exactLength: 32);
    final expectedServerId = encodeBytes(
      (await Sha256().hash(publicKeyBytes)).bytes,
    ).substring(0, 22);
    if (serverId != expectedServerId || !isPrivateIpv4(sourceAddress)) {
      return null;
    }
    // Use the address that answered the discovery packet first. On PCs with
    // VPN, Hyper-V, or virtual adapters this is the interface reachable from
    // the phone's current Wi-Fi network.
    final addresses = <String>{sourceAddress, ...rawAddresses.cast<String>()};
    return DiscoveredHost(
      serverId: serverId,
      name: rawName.trim(),
      addresses: addresses.toList(growable: false),
      port: port,
      signingPublicKey: publicKey as String,
    );
  }

  Future<Map<String, dynamic>?> loadManualEndpoint() async {
    final stored = await _storage.read(key: _manualEndpointStorageKey);
    if (stored == null) return null;
    try {
      final decoded = jsonDecode(stored);
      if (decoded is! Map<String, dynamic> ||
          decoded['address'] is! String ||
          decoded['port'] is! int) {
        return null;
      }
      return decoded;
    } on FormatException {
      return null;
    }
  }

  Future<void> connectManual({
    required String address,
    required int port,
  }) async {
    if (isConnecting) return;
    final normalizedAddress = address.trim();
    if (!isPrivateIpv4(normalizedAddress)) {
      throw const FormatException(
        'Digite o IPv4 local do Windows, por exemplo 192.168.1.20.',
      );
    }
    if (port < 1024 || port > 65535) {
      throw const FormatException('A porta deve ficar entre 1024 e 65535.');
    }
    _isResolvingManual = true;
    _lastError = null;
    _notifyListeners();
    await DiagnosticLog.record(
      'Android',
      'Buscando identidade do servidor em $normalizedAddress:$port/info.',
    );
    final httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await httpClient
          .getUrl(
            Uri(
              scheme: 'http',
              host: normalizedAddress,
              port: port,
              path: '/info',
            ),
          )
          .timeout(const Duration(seconds: 6));
      final response = await request.close().timeout(
        const Duration(seconds: 6),
      );
      if (response.statusCode != HttpStatus.ok ||
          (response.contentLength > 0 && response.contentLength > 8192)) {
        throw HttpException(
          'O servidor respondeu HTTP ${response.statusCode} em /info.',
          uri: request.uri,
        );
      }
      final body = await response.transform(utf8.decoder).join();
      if (body.length > 8192) {
        throw const FormatException('Resposta /info maior que o limite.');
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic> ||
          decoded['type'] != 'open-remote-server' ||
          decoded['version'] != 1) {
        throw const FormatException(
          'O IP e a porta não responderam como servidor Open Remote.',
        );
      }
      final host = await _hostFromDescriptor(
        decoded,
        sourceAddress: normalizedAddress,
      );
      if (host == null) {
        throw const FormatException(
          'O servidor enviou dados de identificação inválidos.',
        );
      }
      await _storage.write(
        key: _manualEndpointStorageKey,
        value: jsonEncode({'address': normalizedAddress, 'port': port}),
      );
      await connectDiscovered(host);
    } catch (error, stackTrace) {
      await DiagnosticLog.record(
        'Android',
        'Conexão manual com $normalizedAddress:$port falhou.',
        error: error,
        stackTrace: stackTrace,
      );
      if (error is SocketException || error is TimeoutException) {
        _lastError = _describeConnectionError(
          error,
          address: normalizedAddress,
          port: port,
        );
      }
      rethrow;
    } finally {
      httpClient.close(force: true);
      _isResolvingManual = false;
      _notifyListeners();
    }
  }

  Future<List<SavedHost>> loadSavedHosts() async {
    final stored = await _storage.read(key: _hostsStorageKey);
    if (stored == null) return const [];
    try {
      final decoded = jsonDecode(stored);
      if (decoded is! List) return const [];
      final result = <SavedHost>[];
      for (final row in decoded) {
        if (row is! Map<String, dynamic> ||
            row['serverId'] is! String ||
            row['name'] is! String ||
            row['addresses'] is! List ||
            row['port'] is! int ||
            row['signingPublicKey'] is! String) {
          continue;
        }
        final addresses = (row['addresses'] as List)
            .whereType<String>()
            .where(isPrivateIpv4)
            .toList(growable: false);
        if (addresses.isEmpty) continue;
        decodeBytes(row['signingPublicKey'], exactLength: 32);
        result.add(
          SavedHost(
            serverId: row['serverId'] as String,
            name: row['name'] as String,
            addresses: addresses,
            port: row['port'] as int,
            signingPublicKey: row['signingPublicKey'] as String,
          ),
        );
      }
      return result;
    } on FormatException {
      return const [];
    }
  }

  Future<void> connectFromQr(PairingInfo pairing) async {
    final profiles = await _readProfiles();
    final profile = profiles[pairing.serverId];
    if (profile == null && DateTime.now().isAfter(pairing.expiresAt)) {
      throw const FormatException(
        'O QR de pareamento expirou. Gere outro no Windows.',
      );
    }
    try {
      await _connect(
        serverId: pairing.serverId,
        addresses: pairing.addresses,
        port: pairing.port,
        signingPublicKey: pairing.signingPublicKey,
        pairingToken: pairing.pairingToken,
        profile: profile,
        requestApproval: false,
      );
    } on _SavedAuthorizationRejected {
      if (profile == null || DateTime.now().isAfter(pairing.expiresAt)) rethrow;
      profiles.remove(pairing.serverId);
      await _writeProfiles(profiles);
      await _connect(
        serverId: pairing.serverId,
        addresses: pairing.addresses,
        port: pairing.port,
        signingPublicKey: pairing.signingPublicKey,
        pairingToken: pairing.pairingToken,
        profile: null,
        requestApproval: false,
      );
    }
  }

  Future<void> connectSaved(SavedHost host) async {
    final profiles = await _readProfiles();
    final profile = profiles[host.serverId];
    if (profile == null) {
      throw const FormatException(
        'Este computador precisa ser pareado novamente.',
      );
    }
    await _connect(
      serverId: host.serverId,
      addresses: host.addresses,
      port: host.port,
      signingPublicKey: host.signingPublicKey,
      pairingToken: '',
      profile: profile,
      requestApproval: false,
    );
  }

  Future<void> connectDiscovered(DiscoveredHost host) async {
    await DiagnosticLog.record(
      'Android',
      'Conectando a ${host.name}; IPs em ordem: ${host.addresses.join(', ')}; porta ${host.port}.',
    );
    final profiles = await _readProfiles();
    var profile = profiles[host.serverId];
    try {
      await _connect(
        serverId: host.serverId,
        addresses: host.addresses,
        port: host.port,
        signingPublicKey: host.signingPublicKey,
        pairingToken: '',
        profile: profile,
        requestApproval: profile == null,
        serverName: host.name,
      );
    } on _SavedAuthorizationRejected {
      if (profile == null) rethrow;
      profiles.remove(host.serverId);
      await _writeProfiles(profiles);
      profile = null;
      await _connect(
        serverId: host.serverId,
        addresses: host.addresses,
        port: host.port,
        signingPublicKey: host.signingPublicKey,
        pairingToken: '',
        profile: profile,
        requestApproval: true,
        serverName: host.name,
      );
    }
  }

  Future<void> _connect({
    required String serverId,
    required List<String> addresses,
    required int port,
    required String signingPublicKey,
    required String pairingToken,
    required Map<String, dynamic>? profile,
    required bool requestApproval,
    String serverName = 'PC Windows',
  }) async {
    if (_isConnecting) return;
    await disconnect();
    _isConnecting = true;
    _lastError = null;
    _notifyListeners();
    final failures = <String>[];
    try {
      await _ensureLocalNetworkPermission();
      for (final address in addresses.where(isPrivateIpv4)) {
        try {
          await DiagnosticLog.record(
            'Android',
            'Abrindo WebSocket em $address:$port/control.',
          );
          await _connectToAddress(
            address: address,
            addresses: addresses,
            serverId: serverId,
            port: port,
            signingPublicKey: signingPublicKey,
            pairingToken: pairingToken,
            profile: profile,
            requestApproval: requestApproval,
            serverName: serverName,
          );
          _connectedAddress = address;
          await DiagnosticLog.record(
            'Android',
            'Conexão segura estabelecida com $address:$port.',
          );
          return;
        } catch (error, stackTrace) {
          final detail = _describeConnectionError(
            error,
            address: address,
            port: port,
          );
          failures.add(detail);
          await DiagnosticLog.record(
            'Android',
            'Falha ao conectar em $address:$port.',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
      throw _ConnectionAttemptsFailed(
        failures.isEmpty
            ? 'Nenhum IP privado válido foi anunciado pelo Windows.'
            : failures.take(4).join('\n'),
      );
    } catch (error, stackTrace) {
      _lastError = error is _ConnectionAttemptsFailed
          ? error.message
          : _describeConnectionError(error);
      await DiagnosticLog.record(
        'Android',
        'Tentativa de conexão encerrada: $_lastError',
        error: error,
        stackTrace: stackTrace,
      );
      await disconnect();
      rethrow;
    } finally {
      _isConnecting = false;
      _notifyListeners();
    }
  }

  Future<void> _ensureLocalNetworkPermission() async {
    if (!Platform.isAndroid) return;
    const channel = MethodChannel('open_remote/permissions');
    final granted = await channel.invokeMethod<bool>(
      'requestLocalNetworkAccess',
    );
    if (granted != true) {
      throw StateError('Permita o acesso à rede local para conectar ao PC.');
    }
  }

  Future<void> _connectToAddress({
    required String address,
    required List<String> addresses,
    required String serverId,
    required int port,
    required String signingPublicKey,
    required String pairingToken,
    required Map<String, dynamic>? profile,
    required bool requestApproval,
    required String serverName,
  }) async {
    final signingPublicKeyBytes = decodeBytes(
      signingPublicKey,
      exactLength: 32,
    );
    final expectedServerId = encodeBytes(
      (await Sha256().hash(signingPublicKeyBytes)).bytes,
    ).substring(0, 22);
    if (serverId != expectedServerId) {
      throw const FormatException('Server identity does not match its key.');
    }
    final uri = Uri(scheme: 'ws', host: address, port: port, path: '/control');
    final socket = await WebSocket.connect(
      uri.toString(),
    ).timeout(const Duration(seconds: 6));
    final iterator = StreamIterator<Object?>(socket);
    try {
      socket.pingInterval = const Duration(seconds: 25);
      final clientEphemeralKey = await _keyExchange.newKeyPair();
      final clientPublicBytes = publicKeyBytes(
        await clientEphemeralKey.extractPublicKey(),
      );
      final clientNonce = secureRandomBytes(16);
      socket.add(
        jsonEncode({
          'type': 'hello',
          'version': 1,
          'clientPublicKey': encodeBytes(clientPublicBytes),
          'clientNonce': encodeBytes(clientNonce),
        }),
      );

      final response = await _nextMap(iterator);
      if (response['type'] != 'server_key' || response['version'] != 1) {
        throw const FormatException('Resposta de handshake inválida.');
      }
      final serverEphemeralBytes = decodeBytes(
        response['serverEphemeralKey'],
        exactLength: 32,
      );
      final serverNonce = decodeBytes(response['serverNonce'], exactLength: 16);
      final signatureBytes = decodeBytes(
        response['signature'],
        exactLength: 64,
      );
      final transcript = _handshakeTranscript(
        clientPublicBytes,
        serverEphemeralBytes,
        clientNonce,
        serverNonce,
      );
      final serverIdentity = SimplePublicKey(
        signingPublicKeyBytes,
        type: KeyPairType.ed25519,
      );
      final signatureValid = await _signatures.verify(
        transcript,
        signature: Signature(signatureBytes, publicKey: serverIdentity),
      );
      if (!signatureValid) {
        throw const FormatException(
          'A identidade do servidor não corresponde ao QR escaneado.',
        );
      }

      final sharedSecret = await _keyExchange.sharedSecretKey(
        keyPair: clientEphemeralKey,
        remotePublicKey: SimplePublicKey(
          serverEphemeralBytes,
          type: KeyPairType.x25519,
        ),
      );
      final session = await SecureSession.derive(
        sharedSecret: sharedSecret,
        clientNonce: clientNonce,
        serverNonce: serverNonce,
        isServer: false,
      );
      final challenge = await session.decrypt(await _nextMap(iterator));
      if (challenge['kind'] != 'challenge' || challenge['nonce'] is! String) {
        throw const FormatException('Desafio de autenticação inválido.');
      }

      final auth = profile == null
          ? <String, Object?>{
              'kind': 'auth',
              'mode': requestApproval ? 'request_pair' : 'pair',
              if (!requestApproval) 'pairingToken': pairingToken,
              'clientName': 'Android',
            }
          : <String, Object?>{
              'kind': 'auth',
              'mode': 'resume',
              'clientId': profile['clientId'],
              'clientToken': profile['clientToken'],
            };
      socket.add(jsonEncode(await session.encrypt(auth)));
      final authResult = await session.decrypt(
        await _nextMap(
          iterator,
          timeout: requestApproval
              ? const Duration(seconds: 90)
              : const Duration(seconds: 8),
        ),
      );
      if (authResult['kind'] == 'auth_error') {
        if (authResult['mode'] == 'resume') {
          throw const _SavedAuthorizationRejected();
        }
        if (authResult['mode'] == 'request_pair') {
          throw const FormatException(
            'Aprove o pedido de conexão no computador Windows.',
          );
        }
        throw const FormatException(
          'Acesso recusado. Gere um novo QR ou confira se este celular ainda está pareado.',
        );
      }
      if (authResult['kind'] != 'auth_ok' ||
          authResult['serverId'] != serverId ||
          authResult['clientId'] is! String ||
          authResult['clientToken'] is! String) {
        throw const FormatException('O servidor recusou o pareamento.');
      }

      await _saveProfile({
        'serverId': serverId,
        'name': serverName,
        'addresses': addresses,
        'port': port,
        'signingPublicKey': signingPublicKey,
        'clientId': authResult['clientId'],
        'clientToken': authResult['clientToken'],
      });
      _socket = socket;
      _iterator = iterator;
      _session = session;
      _connectedServerId = serverId;
      unawaited(_listenForServerMessages(socket, iterator, session));
    } catch (_) {
      await iterator.cancel();
      await socket.close(WebSocketStatus.normalClosure);
      rethrow;
    }
  }

  Future<void> send(Map<String, Object?> command) {
    final socket = _socket;
    final session = _session;
    if (socket == null || session == null) {
      return Future<void>.error(StateError('Nenhum PC está conectado.'));
    }
    _sendQueue = _sendQueue.then((_) async {
      if (_socket != socket || socket.readyState != WebSocket.open) return;
      socket.add(jsonEncode(await session.encrypt(command)));
    });
    return _sendQueue;
  }

  Future<void> sendMouseMove(double dx, double dy) =>
      send({'kind': 'mouse.move', 'dx': dx, 'dy': dy});

  Future<void> sendMouseButton(String button, bool pressed) =>
      send({'kind': 'mouse.button', 'button': button, 'pressed': pressed});

  Future<void> sendScroll(int delta) =>
      send({'kind': 'mouse.scroll', 'delta': delta});

  Future<void> sendText(String text) =>
      send({'kind': 'keyboard.text', 'text': text});

  Future<void> sendKey(String key) =>
      send({'kind': 'keyboard.key', 'key': key});

  Future<void> sendModifier(String key, bool pressed) =>
      send({'kind': 'keyboard.modifier', 'key': key, 'pressed': pressed});

  Future<void> sendMedia(String action) =>
      send({'kind': 'media.command', 'action': action});

  Future<void> disconnect() async {
    final iterator = _iterator;
    _iterator = null;
    _session = null;
    _connectedServerId = null;
    _connectedAddress = null;
    final socket = _socket;
    _socket = null;
    await iterator?.cancel();
    await socket?.close(WebSocketStatus.normalClosure);
    _notifyListeners();
  }

  Future<void> _listenForServerMessages(
    WebSocket socket,
    StreamIterator<Object?> iterator,
    SecureSession session,
  ) async {
    try {
      while (await iterator.moveNext()) {
        final frame = iterator.current;
        final message = await session.decrypt(_decodeFrame(frame));
        if (message['kind'] == 'close') break;
      }
    } catch (_) {
      // Socket teardown is reflected by the connection status below.
    } finally {
      if (_socket == socket) {
        _socket = null;
        _iterator = null;
        _session = null;
        _connectedServerId = null;
        _connectedAddress = null;
        _notifyListeners();
      }
      await iterator.cancel();
      await socket.close(WebSocketStatus.normalClosure);
    }
  }

  String _describeConnectionError(Object error, {String? address, int? port}) {
    final endpoint = address == null
        ? ''
        : ' $address${port == null ? '' : ':$port'}';
    if (error is SocketException) {
      final osError = error.osError;
      final detail = osError == null
          ? error.message
          : '${osError.message} (código ${osError.errorCode})';
      return 'Falha TCP$endpoint: $detail. Confira se o servidor está ativo e se o Firewall do Windows libera a porta ${port ?? 47652}.';
    }
    if (error is TimeoutException) {
      return 'Timeout de rede$endpoint: o PC não respondeu dentro do prazo. Verifique firewall e isolamento de clientes no roteador.';
    }
    return error.toString();
  }

  Future<Map<String, dynamic>> _nextMap(
    StreamIterator<Object?> iterator, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (!await iterator.moveNext().timeout(timeout)) {
      throw SocketException('O servidor encerrou a conexão.');
    }
    return _decodeFrame(iterator.current);
  }

  static Map<String, dynamic> _decodeFrame(Object? frame) {
    if (frame is! String || frame.length > SecureSession.maxFrameBytes * 2) {
      throw const FormatException('Quadro de rede inválido.');
    }
    final decoded = jsonDecode(frame);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Quadro JSON inválido.');
    }
    return decoded;
  }

  Future<Map<String, Map<String, dynamic>>> _readProfiles() async {
    final stored = await _storage.read(key: _hostsStorageKey);
    if (stored == null) return {};
    try {
      final decoded = jsonDecode(stored);
      if (decoded is! List) return {};
      return {
        for (final row in decoded)
          if (row is Map<String, dynamic> &&
              row['serverId'] is String &&
              row['clientId'] is String &&
              row['clientToken'] is String)
            row['serverId'] as String: row,
      };
    } on FormatException {
      return {};
    }
  }

  Future<void> _saveProfile(Map<String, Object?> profile) async {
    final profiles = await _readProfiles();
    profiles[profile['serverId']! as String] = profile;
    await _writeProfiles(profiles);
  }

  Future<void> _writeProfiles(
    Map<String, Map<String, dynamic>> profiles,
  ) async {
    await _storage.write(
      key: _hostsStorageKey,
      value: jsonEncode(profiles.values.toList(growable: false)),
    );
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

  @override
  void dispose() {
    _disposed = true;
    unawaited(disconnect());
    super.dispose();
  }

  void _notifyListeners() {
    if (!_disposed) notifyListeners();
  }
}

class _SavedAuthorizationRejected implements Exception {
  const _SavedAuthorizationRejected();
}

class _ConnectionAttemptsFailed implements Exception {
  const _ConnectionAttemptsFailed(this.message);

  final String message;

  @override
  String toString() => message;
}
