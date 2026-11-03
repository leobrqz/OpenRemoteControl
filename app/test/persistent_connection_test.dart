import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_remote_control/src/client/client_device_identity.dart';
import 'package:open_remote_control/src/client/client_service.dart';
import 'package:open_remote_core/open_remote_core.dart';

class _Pipe {
  final _bytes = <int>[];
  Completer<void>? _changed;
  bool _closed = false;

  Future<void> write(List<int> bytes) async {
    _bytes.addAll(bytes);
    _changed?.complete();
    _changed = null;
  }

  Future<Uint8List?> read(int max) async {
    while (_bytes.isEmpty && !_closed) {
      _changed ??= Completer<void>();
      await _changed!.future;
    }
    if (_bytes.isEmpty) return null;
    final count = max < _bytes.length ? max : _bytes.length;
    final result = Uint8List.fromList(_bytes.take(count).toList());
    _bytes.removeRange(0, count);
    return result;
  }

  Future<void> close() async {
    _closed = true;
    _changed?.complete();
    _changed = null;
  }
}

class _Session {
  _Session(this.channel, this.iterator, this.secure, this.auth);
  final ControlChannel channel;
  final StreamIterator<Object?> iterator;
  final SecureSession secure;
  final Map<String, dynamic> auth;
}

Future<_Session> _accept(
  ControlChannel channel,
  SimpleKeyPair identity,
  String serverId,
) async {
  final iterator = StreamIterator<Object?>(channel);
  if (!await iterator.moveNext()) throw StateError('Missing hello');
  final hello = decodeWireMap(iterator.current);
  final clientPublic = decodeBytes(hello['clientPublicKey'], exactLength: 32);
  final clientNonce = decodeBytes(hello['clientNonce'], exactLength: 16);
  final exchange = X25519();
  final ephemeral = await exchange.newKeyPair();
  final serverPublic = publicKeyBytes(await ephemeral.extractPublicKey());
  final serverNonce = secureRandomBytes(16);
  final transcript = utf8.encode(
    [
      'open-remote/v1/handshake',
      encodeBytes(clientPublic),
      encodeBytes(serverPublic),
      encodeBytes(clientNonce),
      encodeBytes(serverNonce),
    ].join('\n'),
  );
  final signature = await Ed25519().sign(transcript, keyPair: identity);
  channel.add(
    jsonEncode({
      'type': 'server_key',
      'version': 1,
      'serverEphemeralKey': encodeBytes(serverPublic),
      'serverNonce': encodeBytes(serverNonce),
      'signature': encodeBytes(signature.bytes),
    }),
  );
  final shared = await exchange.sharedSecretKey(
    keyPair: ephemeral,
    remotePublicKey: SimplePublicKey(clientPublic, type: KeyPairType.x25519),
  );
  final secure = await SecureSession.derive(
    sharedSecret: shared,
    clientNonce: clientNonce,
    serverNonce: serverNonce,
    isServer: true,
  );
  channel.add(
    jsonEncode(await secure.encrypt({'kind': 'challenge', 'nonce': 'test'})),
  );
  if (!await iterator.moveNext()) throw StateError('Missing authorization');
  final auth = await secure.decryptWireFrame(iterator.current);
  channel.add(
    jsonEncode(
      await secure.encrypt({
        'kind': 'auth_ok',
        'serverId': serverId,
        'clientId': 'phone',
        'clientToken': 'saved-token',
      }),
    ),
  );
  return _Session(channel, iterator, secure, auth);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'pairs by QR, sends an encrypted command, and resumes remotely',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final identity = await Ed25519().newKeyPair();
      final identityBytes = publicKeyBytes(await identity.extractPublicKey());
      final serverId = encodeBytes(
        (await Sha256().hash(identityBytes)).bytes,
      ).substring(0, 22);
      final remoteEndpoint = encodeBytes(List<int>.filled(32, 3));
      final token = encodeBytes(List<int>.filled(32, 4));
      final sessions = StreamController<_Session>();
      final accepted = StreamIterator<_Session>(sessions.stream);
      final client = RemoteClientService(
        deviceIdentityProvider: () async => ClientDeviceIdentity.fallback,
        socketConnector: (_) => throw StateError('LAN should not be used'),
        persistentConnector: (address) async {
          expect(address, remoteEndpoint);
          final toHost = _Pipe();
          final toClient = _Pipe();
          final mobile = FramedControlChannel(
            read: toClient.read,
            write: toHost.write,
            release: toHost.close,
          );
          final host = FramedControlChannel(
            read: toHost.read,
            write: toClient.write,
            release: toClient.close,
          );
          unawaited(
            _accept(
              host,
              identity,
              serverId,
            ).then(sessions.add, onError: sessions.addError),
          );
          return mobile;
        },
      );
      try {
        await client.connectFromQr(
          PairingInfo(
            serverId: serverId,
            addresses: const ['192.168.1.2'],
            port: 47652,
            signingPublicKey: encodeBytes(identityBytes),
            pairingToken: token,
            expiresAt: DateTime.now().add(const Duration(minutes: 2)),
            remoteEndpoint: remoteEndpoint,
          ),
        );
        expect(await accepted.moveNext(), isTrue);
        final first = accepted.current;
        expect(first.auth['mode'], 'pair');
        expect(first.auth['pairingToken'], token);
        expect(
          (await client.loadSavedHosts()).single.remoteEndpoint,
          remoteEndpoint,
        );
        first.channel.add(
          jsonEncode(
            await first.secure.encrypt(
              const VolumeState(level: 42, muted: false).toMessage(),
            ),
          ),
        );
        final deadline = DateTime.now().add(const Duration(seconds: 2));
        while (client.volumeState?.level != 42 &&
            DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(client.volumeState?.level, 42);
        await client.send({'kind': 'media.command', 'action': 'volumeUp'});
        expect(await first.iterator.moveNext(), isTrue);
        expect(await first.secure.decryptWireFrame(first.iterator.current), {
          'kind': 'media.command',
          'action': 'volumeUp',
        });

        await client.disconnect(clearSession: false);
        await first.channel.close();
        await first.iterator.cancel();
        await client.reconnect();
        expect(await accepted.moveNext(), isTrue);
        final second = accepted.current;
        expect(second.auth['mode'], 'resume');
        expect(second.auth['clientToken'], 'saved-token');
        expect(
          (await client.loadSavedHosts()).single.remoteEndpoint,
          remoteEndpoint,
        );
        await client.disconnect();
        await second.channel.close();
        await second.iterator.cancel();
      } finally {
        client.dispose();
        await accepted.cancel();
        await sessions.close();
      }
    },
  );

  test(
    'does not authorize a persistent endpoint with the wrong server identity',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final expectedIdentity = await Ed25519().newKeyPair();
      final wrongIdentity = await Ed25519().newKeyPair();
      final expectedKey = publicKeyBytes(
        await expectedIdentity.extractPublicKey(),
      );
      final serverId = encodeBytes(
        (await Sha256().hash(expectedKey)).bytes,
      ).substring(0, 22);
      final toHost = _Pipe();
      final toClient = _Pipe();
      final mobile = FramedControlChannel(
        read: toClient.read,
        write: toHost.write,
        release: toHost.close,
      );
      final host = FramedControlChannel(
        read: toHost.read,
        write: toClient.write,
        release: toClient.close,
      );
      final serverFinished = _accept(
        host,
        wrongIdentity,
        serverId,
      ).then<void>((_) {}, onError: (Object _, StackTrace _) {});
      final client = RemoteClientService(
        deviceIdentityProvider: () async => ClientDeviceIdentity.fallback,
        persistentConnector: (_) async => mobile,
      );
      try {
        await expectLater(
          client.connectFromQr(
            PairingInfo(
              serverId: serverId,
              addresses: const ['192.168.1.2'],
              port: 47652,
              signingPublicKey: encodeBytes(expectedKey),
              pairingToken: encodeBytes(List<int>.filled(32, 4)),
              expiresAt: DateTime.now().add(const Duration(minutes: 2)),
              remoteEndpoint: encodeBytes(List<int>.filled(32, 3)),
            ),
          ),
          throwsA(isA<Exception>()),
        );
        await serverFinished.timeout(const Duration(seconds: 2));
        expect(await client.loadSavedHosts(), isEmpty);
        expect(client.isConnected, isFalse);
      } finally {
        await host.close();
        client.dispose();
      }
    },
  );
}
