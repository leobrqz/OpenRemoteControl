import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_remote_control/src/core/secure_session.dart';

void main() {
  test('client commands continue the sequence after authentication', () async {
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
    expect(await client.decrypt(challenge), {'kind': 'challenge'});

    final auth = await client.encrypt({'kind': 'auth'});
    expect(auth['sequence'], 0);
    expect(await server.decrypt(auth), {'kind': 'auth'});

    final authOk = await server.encrypt({'kind': 'auth_ok'});
    expect(authOk['sequence'], 1);
    expect(await client.decrypt(authOk), {'kind': 'auth_ok'});

    final command = await client.encrypt({'kind': 'mouse.move'});
    expect(command['sequence'], 1);
    expect(await server.decrypt(command), {'kind': 'mouse.move'});
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
}
