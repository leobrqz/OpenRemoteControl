import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

const int localDiscoveryPort = 47653;
const int maxWireFrameCharacters = 8192;

Map<String, dynamic> decodeWireMap(Object? frame) {
  if (frame is! String || frame.length > maxWireFrameCharacters) {
    throw const FormatException('Quadro de rede inválido.');
  }
  final decoded = jsonDecode(frame);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Quadro JSON inválido.');
  }
  return decoded;
}

String encodeBytes(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

Uint8List decodeBytes(Object? value, {int? exactLength}) {
  if (value is! String || value.length > 4096) {
    throw const FormatException('Campo binário inválido.');
  }
  final bytes = Uint8List.fromList(
    base64Url.decode(base64Url.normalize(value)),
  );
  if (exactLength != null && bytes.length != exactLength) {
    throw const FormatException('Tamanho binário inválido.');
  }
  return bytes;
}

Uint8List secureRandomBytes(int length) {
  final random = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(length, (_) => random.nextInt(256)),
  );
}

Uint8List publicKeyBytes(PublicKey publicKey) {
  if (publicKey is! SimplePublicKey) {
    throw const FormatException('Tipo de chave pública inválido.');
  }
  return Uint8List.fromList(publicKey.bytes);
}

bool isPrivateIpv4(String address) {
  final parts = address.split('.');
  if (parts.length != 4) return false;
  final octets = parts.map(int.tryParse).toList();
  if (octets.any((part) => part == null || part < 0 || part > 255)) {
    return false;
  }
  final first = octets[0]!;
  final second = octets[1]!;
  return first == 10 ||
      (first == 172 && second >= 16 && second <= 31) ||
      (first == 192 && second == 168) ||
      (first == 100 && second >= 64 && second <= 127);
}

class DiscoveredHost {
  const DiscoveredHost({
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

class PairingInfo {
  const PairingInfo({
    required this.serverId,
    required this.addresses,
    required this.port,
    required this.signingPublicKey,
    required this.pairingToken,
    required this.expiresAt,
  });

  final String serverId;
  final List<String> addresses;
  final int port;
  final String signingPublicKey;
  final String pairingToken;
  final DateTime expiresAt;

  String toQrPayload() => jsonEncode({
    'type': 'open-remote-pairing',
    'version': 1,
    'serverId': serverId,
    'addresses': addresses,
    'port': port,
    'signingPublicKey': signingPublicKey,
    'pairingToken': pairingToken,
    'expiresAt': expiresAt.millisecondsSinceEpoch,
  });

  factory PairingInfo.fromQr(String rawValue) {
    if (rawValue.length > 4096) {
      throw const FormatException('QR grande demais.');
    }
    final decoded = jsonDecode(rawValue);
    if (decoded is! Map<String, dynamic> ||
        decoded['type'] != 'open-remote-pairing' ||
        decoded['version'] != 1) {
      throw const FormatException('Este QR não é de um servidor Open Remote.');
    }
    final rawAddresses = decoded['addresses'];
    final port = decoded['port'];
    final expiresAt = decoded['expiresAt'];
    final serverId = decoded['serverId'];
    final publicKey = decoded['signingPublicKey'];
    final pairingToken = decoded['pairingToken'];
    if (rawAddresses is! List ||
        rawAddresses.isEmpty ||
        rawAddresses.length > 8 ||
        rawAddresses.any(
          (address) => address is! String || !isPrivateIpv4(address),
        ) ||
        port is! int ||
        port < 1024 ||
        port > 65535 ||
        expiresAt is! int ||
        serverId is! String ||
        serverId.length > 64 ||
        pairingToken is! String ||
        pairingToken.length > 128) {
      throw const FormatException('Dados do QR inválidos.');
    }
    decodeBytes(publicKey, exactLength: 32);
    decodeBytes(pairingToken, exactLength: 32);
    return PairingInfo(
      serverId: serverId,
      addresses: List<String>.unmodifiable(rawAddresses.cast<String>()),
      port: port,
      signingPublicKey: publicKey,
      pairingToken: pairingToken,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAt),
    );
  }
}
