import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:open_remote_core/open_remote_core.dart';

import 'client_device_identity.dart';
import 'models/saved_host.dart';
import 'repositories/host_repository.dart';
export 'models/saved_host.dart';

class RemoteClientService extends ChangeNotifier {
  RemoteClientService({
    FlutterSecureStorage? storage,
    HostRepository? repository,
    Future<ClientDeviceIdentity> Function()? deviceIdentityProvider,
  }) : _repository = repository ?? SecureHostRepository(storage: storage),
       _deviceIdentityProvider =
           deviceIdentityProvider ?? ClientDeviceIdentity.load;

  final HostRepository _repository;
  final Future<ClientDeviceIdentity> Function() _deviceIdentityProvider;
  final X25519 _keyExchange = X25519();
  final Ed25519 _signatures = Ed25519();

  WebSocket? _socket;
  WebSocket? _pendingSocket;
  StreamIterator<Object?>? _iterator;
  SecureSession? _session;
  Future<void> _sendQueue = Future<void>.value();
  bool _isConnecting = false;
  bool _isResolvingManual = false;
  bool _isDiscovering = false;
  String? _connectedAddress;
  SavedHost? _lastConnectedHost;
  String? _lastError;
  List<DiscoveredHost> _discoveredHosts = const [];
  bool _disposed = false;
  int _connectionGeneration = 0;

  bool get isConnected => _socket != null;
  bool get hasSession => _lastConnectedHost != null;
  bool get isConnecting => _isConnecting || _isResolvingManual;
  bool get isDiscovering => _isDiscovering;
  List<DiscoveredHost> get discoveredHosts => _discoveredHosts;
  String? get connectedAddress => _connectedAddress;
  String? get lastError => _lastError;
  SavedHost? get currentHost => _lastConnectedHost;

  Future<void> forgetHost(String serverId) async {
    await _repository.forgetHost(serverId);
    if (_lastConnectedHost?.serverId == serverId) await disconnect();
  }

  Future<void> updateDiscoveredAddresses() =>
      _repository.updateDiscoveredAddresses(_discoveredHosts);

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
        while (true) {
          final datagram = socket!.receive();
          if (datagram == null) break;
          if (datagram.data.length <= 4096) packets.add(datagram);
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

  Future<Map<String, dynamic>?> loadManualEndpoint() =>
      _repository.loadManualEndpoint();

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
      await _repository.saveManualEndpoint(normalizedAddress, port);
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

  Future<List<SavedHost>> loadSavedHosts() => _repository.loadSavedHosts();

  Future<void> connectFromQr(PairingInfo pairing) async {
    final profiles = await _repository.readProfiles();
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
      await _repository.writeProfiles(profiles);
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
    final profiles = await _repository.readProfiles();
    final profile = profiles[host.serverId];
    if (profile == null) {
      throw const FormatException(
        'Este computador precisa ser pareado novamente.',
      );
    }
    await _connect(
      serverId: host.serverId,
      addresses:
          (profile['addresses'] as List?)
              ?.whereType<String>()
              .where(isPrivateIpv4)
              .toList() ??
          host.addresses,
      port: profile['port'] is int ? profile['port'] as int : host.port,
      signingPublicKey: host.signingPublicKey,
      pairingToken: '',
      profile: profile,
      requestApproval: false,
      serverName: host.name,
    );
  }

  Future<void> reconnect() async {
    final host = _lastConnectedHost;
    if (host == null || _isConnecting) return;
    await connectSaved(host);
  }

  Future<void> connectDiscovered(DiscoveredHost host) async {
    await DiagnosticLog.record(
      'Android',
      'Conectando a ${host.name}; IPs em ordem: ${host.addresses.join(', ')}; porta ${host.port}.',
    );
    final profiles = await _repository.readProfiles();
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
      await _repository.writeProfiles(profiles);
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
    _isConnecting = true;
    final generation = ++_connectionGeneration;
    await disconnect(clearSession: false);
    _lastError = null;
    _notifyListeners();
    final failures = <String>[];
    try {
      if (generation != _connectionGeneration || _disposed) {
        throw const _ConnectionCancelled();
      }
      await _ensureLocalNetworkPermission();
      final deviceIdentity = await _loadDeviceIdentity();
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
            deviceIdentity: deviceIdentity,
            serverName: serverName,
            generation: generation,
          );
          _connectedAddress = address;
          _lastConnectedHost = SavedHost(
            serverId: serverId,
            name: serverName,
            addresses: addresses.where(isPrivateIpv4).toList(growable: false),
            port: port,
            signingPublicKey: signingPublicKey,
          );
          await DiagnosticLog.record(
            'Android',
            'Conexão segura estabelecida com $address:$port.',
          );
          return;
        } on _ConnectionCancelled {
          rethrow;
        } on _SavedAuthorizationRejected {
          rethrow;
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
      if (error is _ConnectionCancelled ||
          generation != _connectionGeneration ||
          _disposed) {
        return;
      }
      if (error is _SavedAuthorizationRejected) _lastConnectedHost = null;
      _lastError = error is _ConnectionAttemptsFailed
          ? error.message
          : _describeConnectionError(error);
      await DiagnosticLog.record(
        'Android',
        'Tentativa de conexão encerrada: $_lastError',
        error: error,
        stackTrace: stackTrace,
      );
      await disconnect(clearSession: false);
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

  Future<ClientDeviceIdentity> _loadDeviceIdentity() async {
    try {
      return await _deviceIdentityProvider().timeout(
        const Duration(seconds: 2),
      );
    } catch (_) {
      // Device details are optional and must not stop a connection.
      return ClientDeviceIdentity.fallback;
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
    required ClientDeviceIdentity deviceIdentity,
    required String serverName,
    required int generation,
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
      if (generation != _connectionGeneration || _disposed) {
        throw const _ConnectionCancelled();
      }
      _pendingSocket = socket;
      socket.pingInterval = const Duration(seconds: 20);
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
              ...deviceIdentity.authFields,
            }
          : <String, Object?>{
              'kind': 'auth',
              'mode': 'resume',
              'clientId': profile['clientId'],
              'clientToken': profile['clientToken'],
              ...deviceIdentity.authFields,
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

      await _repository.saveProfile({
        'serverId': serverId,
        'name': serverName,
        'addresses': addresses,
        'port': port,
        'signingPublicKey': signingPublicKey,
        'clientId': authResult['clientId'],
        'clientToken': authResult['clientToken'],
      });
      if (generation != _connectionGeneration || _disposed) {
        throw const _ConnectionCancelled();
      }
      _socket = socket;
      _pendingSocket = null;
      _iterator = iterator;
      _session = session;
      unawaited(_listenForServerMessages(socket, iterator, session));
    } catch (_) {
      if (_pendingSocket == socket) _pendingSocket = null;
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
    final operation = _sendQueue.then((_) async {
      if (_socket != socket || socket.readyState != WebSocket.open) return;
      socket.add(jsonEncode(await session.encrypt(command)));
    });
    _sendQueue = operation.catchError((Object error, StackTrace stackTrace) {
      unawaited(
        DiagnosticLog.record(
          'Android',
          'Falha enviando comando ao PC.',
          error: error,
          stackTrace: stackTrace,
        ),
      );
    });
    return operation;
  }

  Future<void> disconnect({bool clearSession = true}) async {
    final pending = _pendingSocket;
    _pendingSocket = null;
    final iterator = _iterator;
    _iterator = null;
    _session = null;
    if (clearSession) {
      _connectionGeneration++;
      _connectedAddress = null;
      _lastConnectedHost = null;
      _lastError = null;
    }
    final socket = _socket;
    _socket = null;
    await pending?.close(WebSocketStatus.normalClosure);
    await iterator?.cancel();
    await socket?.close(WebSocketStatus.normalClosure);
    _notifyListeners();
  }

  Future<void> _listenForServerMessages(
    WebSocket socket,
    StreamIterator<Object?> iterator,
    SecureSession session,
  ) async {
    Object? disconnectReason;
    try {
      while (await iterator.moveNext()) {
        final frame = iterator.current;
        final message = await session.decryptWireFrame(frame);
        if (message['kind'] == 'close') break;
      }
    } catch (error, stackTrace) {
      disconnectReason = error;
      await DiagnosticLog.record(
        'Android',
        'Conexão segura encerrada pelo servidor.',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      if (_socket == socket) {
        _socket = null;
        _iterator = null;
        _session = null;
        _lastError = disconnectReason == null
            ? 'O PC encerrou a conexão.'
            : 'Conexão perdida: $disconnectReason';
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
    return decodeWireMap(iterator.current);
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

  @override
  String toString() =>
      'O PC removeu a autorização deste celular. Solicite uma nova conexão.';
}

class _ConnectionCancelled implements Exception {
  const _ConnectionCancelled();
}

class _ConnectionAttemptsFailed implements Exception {
  const _ConnectionAttemptsFailed(this.message);

  final String message;

  @override
  String toString() => message;
}
