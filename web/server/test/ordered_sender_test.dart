import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_remote_core/open_remote_core.dart';
import 'package:open_remote_server/src/host/ordered_sender.dart';

void main() {
  test(
    'concurrent audio batches retain secure sequence and message order',
    () async {
      final secret = SecretKey(List<int>.filled(32, 1));
      final nonce = List<int>.filled(16, 2);
      final senderSession = await SecureSession.derive(
        sharedSecret: secret,
        clientNonce: nonce,
        serverNonce: nonce,
        isServer: true,
      );
      final receiverSession = await SecureSession.derive(
        sharedSecret: secret,
        clientNonce: nonce,
        serverNonce: nonce,
        isServer: false,
      );
      final firstEncryption = Completer<void>();
      final wire = <String>[];
      final sender = OrderedSender((message) async {
        if (message['value'] == 1) await firstEncryption.future;
        wire.add(jsonEncode(await senderSession.encrypt(message)));
      });
      final mixer = sender.send([
        {'value': 1},
        {'value': 2},
      ]);
      final volume = sender.send([
        {'value': 3},
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(wire, isEmpty);
      firstEncryption.complete();
      await Future.wait([mixer, volume]);
      final decoded = <Object?>[];
      for (final frame in wire) {
        decoded.add((await receiverSession.decryptWireFrame(frame))['value']);
      }
      expect(decoded, [1, 2, 3]);
    },
  );
}
