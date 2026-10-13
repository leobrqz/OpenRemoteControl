import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'wire.dart';

class SecureSession {
  SecureSession._({
    required SecretKey sendKey,
    required SecretKey receiveKey,
    required String sendDirection,
    required String receiveDirection,
  }) : _sendKey = sendKey,
       _receiveKey = receiveKey,
       _sendDirection = sendDirection,
       _receiveDirection = receiveDirection;

  static const maxFrameBytes = 4096;
  static final _cipher = AesGcm.with256bits();
  final SecretKey _sendKey;
  final SecretKey _receiveKey;
  final String _sendDirection;
  final String _receiveDirection;
  int _nextSendSequence = 0;
  int _nextReceiveSequence = 0;

  static Future<SecureSession> derive({
    required SecretKey sharedSecret,
    required List<int> clientNonce,
    required List<int> serverNonce,
    required bool isServer,
  }) async {
    final salt = <int>[...clientNonce, ...serverNonce];
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final clientToServer = await hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: salt,
      info: utf8.encode('open-remote/v1/client-to-server'),
    );
    final serverToClient = await hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: salt,
      info: utf8.encode('open-remote/v1/server-to-client'),
    );
    return SecureSession._(
      sendKey: isServer ? serverToClient : clientToServer,
      receiveKey: isServer ? clientToServer : serverToClient,
      sendDirection: isServer ? 'server-to-client' : 'client-to-server',
      receiveDirection: isServer ? 'client-to-server' : 'server-to-client',
    );
  }

  Future<Map<String, Object>> encrypt(Map<String, Object?> message) async {
    // Dart integers are signed; 0xFFFFFFFFFFFFFFFF is -1 on the VM, so
    // comparing a fresh sequence number against it rejects every first frame.
    if (_nextSendSequence >= 0x7FFFFFFFFFFFFFFF) {
      throw StateError('Limite de sequência da sessão atingido.');
    }
    final sequence = _nextSendSequence++;
    final clearText = utf8.encode(jsonEncode(message));
    if (clearText.length > maxFrameBytes) {
      throw const FormatException('Comando grande demais.');
    }
    final nonce = _nonce(sequence, _sendDirection);
    final aad = utf8.encode('open-remote/v1/$_sendDirection/$sequence');
    final box = await _cipher.encrypt(
      clearText,
      secretKey: _sendKey,
      nonce: nonce,
      aad: aad,
    );
    return {
      'type': 'secure',
      'version': 1,
      'sequence': sequence,
      'cipherText': encodeBytes(box.cipherText),
      'tag': encodeBytes(box.mac.bytes),
    };
  }

  Future<Map<String, dynamic>> decrypt(Object? frame) async {
    if (frame is! Map<String, dynamic> ||
        frame['type'] != 'secure' ||
        frame['version'] != 1 ||
        frame['sequence'] != _nextReceiveSequence) {
      throw const FormatException('Sequência de sessão inválida.');
    }
    final sequence = _nextReceiveSequence;
    final cipherText = decodeBytes(frame['cipherText']);
    final tag = decodeBytes(frame['tag'], exactLength: 16);
    if (cipherText.length > maxFrameBytes) {
      throw const FormatException('Comando criptografado grande demais.');
    }
    final clearText = await _cipher.decrypt(
      SecretBox(
        cipherText,
        nonce: _nonce(sequence, _receiveDirection),
        mac: Mac(tag),
      ),
      secretKey: _receiveKey,
      aad: utf8.encode('open-remote/v1/$_receiveDirection/$sequence'),
    );
    final decoded = jsonDecode(utf8.decode(clearText));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Mensagem da sessão inválida.');
    }
    _nextReceiveSequence++;
    return decoded;
  }

  static Uint8List _nonce(int sequence, String direction) {
    final nonce = Uint8List(12);
    nonce[0] = direction == 'client-to-server' ? 0x43 : 0x53;
    ByteData.sublistView(nonce).setUint64(4, sequence, Endian.big);
    return nonce;
  }
}
