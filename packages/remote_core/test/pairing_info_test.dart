import 'dart:convert';

import 'package:open_remote_core/open_remote_core.dart';
import 'package:test/test.dart';

void main() {
  final info = PairingInfo(
    serverId: 'server',
    addresses: const ['192.168.1.10'],
    port: 47652,
    signingPublicKey: encodeBytes(List.filled(32, 1)),
    pairingToken: encodeBytes(List.filled(32, 2)),
    expiresAt: DateTime.fromMillisecondsSinceEpoch(2000000000000),
    remoteEndpoint: encodeBytes(List.filled(32, 3)),
  );

  test('round trips an optional persistent endpoint', () {
    expect(
      PairingInfo.fromQr(info.toQrPayload()).remoteEndpoint,
      info.remoteEndpoint,
    );
    final legacy = jsonDecode(info.toQrPayload()) as Map<String, dynamic>;
    legacy.remove('remoteEndpoint');
    expect(PairingInfo.fromQr(jsonEncode(legacy)).remoteEndpoint, isNull);
  });

  test('rejects a malformed persistent endpoint', () {
    final invalid = jsonDecode(info.toQrPayload()) as Map<String, dynamic>;
    invalid['remoteEndpoint'] = encodeBytes([1, 2]);
    expect(
      () => PairingInfo.fromQr(jsonEncode(invalid)),
      throwsFormatException,
    );
  });
}
