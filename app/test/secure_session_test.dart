import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_remote_control/src/core/secure_session.dart';

void main() {
  test('client commands continue over JSON WebSocket frames', () async {
    final sharedSecret = SecretKey(List<int>.generate(32, (index) => index));
    final clientNonce = List<int>.generate(16, (index) => index + 16);
    final serverNonce = List<int>.generate(16, (index) => index + 32);
    final client = await SecureSession.derive(
      sharedSecret: sharedSecret,
      clientNonce: clientNonce,
      serverNonce: serverNonce,
      isServer: false,
    );
    final server = await SecureSession.derive(
      sharedSecret: sharedSecret,
      clientNonce: clientNonce,
      serverNonce: serverNonce,
      isServer: true,
    );

    final challenge = await server.encrypt({'kind': 'challenge'});
    expect(await client.decryptWireFrame(jsonEncode(challenge)), {
      'kind': 'challenge',
    });

    final auth = await client.encrypt({'kind': 'auth'});
    expect(auth['sequence'], 0);
    expect(await server.decryptWireFrame(jsonEncode(auth)), {'kind': 'auth'});

    final authOk = await server.encrypt({'kind': 'auth_ok'});
    expect(authOk['sequence'], 1);
    expect(await client.decryptWireFrame(jsonEncode(authOk)), {
      'kind': 'auth_ok',
    });

    final command = await client.encrypt({'kind': 'mouse.move'});
    expect(command['sequence'], 1);
    expect(await server.decryptWireFrame(jsonEncode(command)), {
      'kind': 'mouse.move',
    });
  });

  test('rejects a repeated frame sequence with a useful error', () async {
    final sharedSecret = SecretKey(List<int>.generate(32, (index) => index));
    final clientNonce = List<int>.generate(16, (index) => index + 16);
    final serverNonce = List<int>.generate(16, (index) => index + 32);
    final client = await SecureSession.derive(
      sharedSecret: sharedSecret,
      clientNonce: clientNonce,
      serverNonce: serverNonce,
      isServer: false,
    );
    final server = await SecureSession.derive(
      sharedSecret: sharedSecret,
      clientNonce: clientNonce,
      serverNonce: serverNonce,
      isServer: true,
    );
    final frame = await client.encrypt({'kind': 'auth'});
    await server.decrypt(frame);

    await expectLater(
      server.decrypt(frame),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('recebida 0, esperada 1'),
        ),
      ),
    );
  });

  test('decrypts a command received as a real WebSocket text frame', () async {
    final sharedSecret = SecretKey(List<int>.generate(32, (index) => index));
    final clientNonce = List<int>.generate(16, (index) => index + 16);
    final serverNonce = List<int>.generate(16, (index) => index + 32);
    final client = await SecureSession.derive(
      sharedSecret: sharedSecret,
      clientNonce: clientNonce,
      serverNonce: serverNonce,
      isServer: false,
    );
    final host = await SecureSession.derive(
      sharedSecret: sharedSecret,
      clientNonce: clientNonce,
      serverNonce: serverNonce,
      isServer: true,
    );
    final received = Completer<Map<String, dynamic>>();
    final httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = httpServer.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      await for (final frame in socket) {
        received.complete(await host.decryptWireFrame(frame));
      }
    });
    final clientSocket = await WebSocket.connect(
      'ws://127.0.0.1:${httpServer.port}/control',
    );
    try {
      clientSocket.add(
        jsonEncode(
          await client.encrypt({'kind': 'mouse.move', 'dx': 0, 'dy': 0}),
        ),
      );
      expect(await received.future.timeout(const Duration(seconds: 3)), {
        'kind': 'mouse.move',
        'dx': 0,
        'dy': 0,
      });
    } finally {
      await clientSocket.close();
      await subscription.cancel();
      await httpServer.close(force: true);
    }
  });
}
