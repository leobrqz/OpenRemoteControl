import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_remote_control/src/client/client_device_identity.dart';
import 'package:open_remote_control/src/client/client_service.dart';
import 'package:open_remote_core/open_remote_core.dart';

class _ServerSession {
  _ServerSession(this.socket, this.iterator, this.secure, this.auth);
  final WebSocket socket;
  final StreamIterator<Object?> iterator;
  final SecureSession secure;
  final Map<String, dynamic> auth;

  Future<void> send(Map<String, Object?> message) async {
    socket.add(jsonEncode(await secure.encrypt(message)));
  }
}

Future<void> _waitFor(
  bool Function() condition, [
  String label = 'state',
]) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('$label did not arrive');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'receives encrypted volume updates and clears them on disconnect',
    () async {
      final identity = await Ed25519().newKeyPair();
      final identityBytes = publicKeyBytes(await identity.extractPublicKey());
      final serverId = encodeBytes(
        (await Sha256().hash(identityBytes)).bytes,
      ).substring(0, 22);
      final host = SavedHost(
        serverId: serverId,
        name: 'Test PC',
        addresses: const ['192.168.1.2'],
        port: 47652,
        signingPublicKey: encodeBytes(identityBytes),
      );
      FlutterSecureStorage.setMockInitialValues({
        'orc.client.hosts.v1': jsonEncode([
          {
            'serverId': serverId,
            'name': host.name,
            'addresses': host.addresses,
            'port': host.port,
            'signingPublicKey': host.signingPublicKey,
            'clientId': 'phone',
            'clientToken': 'token',
          },
        ]),
      });

      final http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final sessions = StreamController<_ServerSession>();
      final serverSubscription = http.listen((request) async {
        try {
          final socket = await WebSocketTransformer.upgrade(request);
          final iterator = StreamIterator<Object?>(socket);
          await iterator.moveNext();
          final hello = decodeWireMap(iterator.current);
          final clientPublic = decodeBytes(
            hello['clientPublicKey'],
            exactLength: 32,
          );
          final clientNonce = decodeBytes(
            hello['clientNonce'],
            exactLength: 16,
          );
          final exchange = X25519();
          final ephemeral = await exchange.newKeyPair();
          final serverPublic = publicKeyBytes(
            await ephemeral.extractPublicKey(),
          );
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
          socket.add(
            jsonEncode({
              'type': 'server_key',
              'version': 1,
              'serverEphemeralKey': encodeBytes(serverPublic),
              'serverNonce': encodeBytes(serverNonce),
              'signature': encodeBytes(signature.bytes),
            }),
          );
          final secret = await exchange.sharedSecretKey(
            keyPair: ephemeral,
            remotePublicKey: SimplePublicKey(
              clientPublic,
              type: KeyPairType.x25519,
            ),
          );
          final secure = await SecureSession.derive(
            sharedSecret: secret,
            clientNonce: clientNonce,
            serverNonce: serverNonce,
            isServer: true,
          );
          socket.add(
            jsonEncode(
              await secure.encrypt({'kind': 'challenge', 'nonce': 'test'}),
            ),
          );
          await iterator.moveNext();
          final auth = await secure.decryptWireFrame(iterator.current);
          socket.add(
            jsonEncode(
              await secure.encrypt({
                'kind': 'auth_ok',
                'clientId': 'phone',
                'clientToken': 'token',
                'serverId': serverId,
              }),
            ),
          );
          sessions.add(_ServerSession(socket, iterator, secure, auth));
        } catch (error, stackTrace) {
          sessions.addError(error, stackTrace);
        }
      });
      final accepted = StreamIterator(sessions.stream);
      final client = RemoteClientService(
        deviceIdentityProvider: () async => ClientDeviceIdentity.fallback,
        socketConnector: (_) =>
            WebSocket.connect('ws://127.0.0.1:${http.port}/control'),
      );
      final observed = <VolumeState?>[];
      client.addListener(() => observed.add(client.volumeState));

      try {
        await client.connectSaved(host);
        expect(await accepted.moveNext(), true);
        final first = accepted.current;
        expect(first.auth['features'], contains(volumeStateFeature));
        expect(first.auth['features'], contains(audioMixerFeature));
        expect(client.volumeState, isNull);
        expect(client.audioSessions, isNull);

        await first.send(
          const VolumeState(level: 60, muted: false).toMessage(),
        );
        await _waitFor(() => client.volumeState?.level == 60, 'initial volume');
        await first.send({
          'kind': volumeStateFeature,
          'level': 120,
          'muted': false,
        });
        await first.send(const VolumeState(level: 60, muted: true).toMessage());
        await _waitFor(() => client.volumeState?.muted == true, 'muted volume');
        expect(observed.whereType<VolumeState>(), [
          const VolumeState(level: 60, muted: false),
          const VolumeState(level: 60, muted: true),
        ]);

        final apps = List.generate(
          24,
          (index) => AudioAppState(
            id: '${index + 1}',
            name: '🎵' * 80,
            device: 'Speakers',
            level: 40,
            muted: false,
            systemSounds: false,
          ),
        );
        final chunks = audioMixerFrames(apps, 0);
        expect(chunks.length, greaterThan(1));
        await first.send(chunks.first);
        await first.send(
          const VolumeState(level: 61, muted: false).toMessage(),
        );
        await _waitFor(
          () => client.volumeState?.level == 61,
          'interleaved volume',
        );
        expect(client.audioSessions, isNull);
        for (final chunk in chunks.skip(1)) {
          await first.send(chunk);
        }
        await _waitFor(
          () => client.audioSessions?.length == apps.length,
          'mixer snapshot',
        );
        expect(client.audioSessions, apps);

        await client.send({'kind': 'media.command', 'action': 'volumeUp'});
        expect(await first.iterator.moveNext(), true);
        expect(await first.secure.decryptWireFrame(first.iterator.current), {
          'kind': 'media.command',
          'action': 'volumeUp',
        });
        await client.send({
          'kind': 'audio.session.level',
          'id': '1',
          'level': 70,
        });
        expect(await first.iterator.moveNext(), true);
        expect(await first.secure.decryptWireFrame(first.iterator.current), {
          'kind': 'audio.session.level',
          'id': '1',
          'level': 70,
        });

        await first.send(audioMixerFrames(null, 1).single);
        await _waitFor(() => client.audioSessions == null, 'unavailable mixer');
        await first.send(audioMixerFrames([apps.first], 2).single);
        await _waitFor(
          () => client.audioSessions?.length == 1,
          'recovered mixer',
        );

        await first.send({
          'kind': volumeStateFeature,
          'level': null,
          'muted': null,
        });
        await _waitFor(() => client.volumeState == null, 'unavailable volume');
        await first.send(
          const VolumeState(level: 10, muted: false).toMessage(),
        );
        await _waitFor(
          () => client.volumeState?.level == 10,
          'recovered volume',
        );
        await first.socket.close();
        await _waitFor(() => !client.isConnected, 'disconnect');
        expect(client.volumeState, isNull);
        expect(client.audioSessions, isNull);

        await client.reconnect();
        expect(await accepted.moveNext(), true);
        final second = accepted.current;
        expect(client.volumeState, isNull);
        expect(client.audioSessions, isNull);
        await second.send(
          const VolumeState(level: 78, muted: false).toMessage(),
        );
        await _waitFor(
          () => client.volumeState?.level == 78,
          'reconnected volume',
        );
        await client.disconnect();
        expect(client.volumeState, isNull);
        await second.iterator.cancel();
        await first.iterator.cancel();
      } finally {
        await client.disconnect();
        client.dispose();
        await accepted.cancel();
        await serverSubscription.cancel();
        await http.close(force: true);
        await sessions.close();
      }
    },
  );
}
