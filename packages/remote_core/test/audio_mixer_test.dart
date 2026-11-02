import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:open_remote_core/open_remote_core.dart';
import 'package:test/test.dart';

AudioAppState app(int id, {int level = 50, bool muted = false}) =>
    AudioAppState(
      id: '$id',
      name: '🎵' * 80,
      device: 'Speaker',
      level: level,
      muted: muted,
      systemSounds: false,
    );

void main() {
  test('validates audio sessions without trusting the host payload', () {
    expect(AudioAppState.fromMap(app(1).toMap()), app(1));
    for (final changes in [
      {'id': '0'},
      {'id': 'x'},
      {'id': '1' * 21},
      {'level': 101},
      {'level': -1},
      {'muted': 1},
      {'systemSounds': null},
      {'name': 'x' * 81},
      {'device': 'bad\nname'},
    ]) {
      expect(AudioAppState.fromMap({...app(1).toMap(), ...changes}), isNull);
    }
  });

  test(
    'chunks large snapshots and commits only complete ordered frames',
    () async {
      final source = List.generate(70, (i) => app(i + 1));
      final frames = audioMixerFrames(source, 7);
      expect(frames.length, greaterThan(1));
      expect(
        frames.every((frame) => utf8.encode(jsonEncode(frame)).length <= 3000),
        isTrue,
      );
      final secret = SecretKey(List<int>.filled(32, 4));
      final nonce = List<int>.filled(16, 5);
      final server = await SecureSession.derive(
        sharedSecret: secret,
        clientNonce: nonce,
        serverNonce: nonce,
        isServer: true,
      );
      final client = await SecureSession.derive(
        sharedSecret: secret,
        clientNonce: nonce,
        serverNonce: nonce,
        isServer: false,
      );
      for (final frame in frames) {
        expect(
          await client.decryptWireFrame(
            jsonEncode(await server.encrypt(frame)),
          ),
          frame,
        );
      }
      final assembler = AudioMixerAssembler();
      for (final frame in frames.take(frames.length - 1)) {
        expect(assembler.add(frame), isNull);
      }
      expect(assembler.add(frames.last)!.sessions, source);
      expect(assembler.add(frames.last), isNull);
      final unavailable = assembler.add(audioMixerFrames(null, 8).single);
      expect(unavailable, isNotNull);
      expect(unavailable!.sessions, isNull);
      expect(assembler.add(audioMixerFrames([], 9).single)!.sessions, isEmpty);
    },
  );

  test('discards missing, malformed and duplicate parts', () {
    final frames = audioMixerFrames(List.generate(20, (i) => app(i + 1)), 1);
    final assembler = AudioMixerAssembler();
    expect(assembler.add(frames[1]), isNull);
    expect(assembler.add(frames[0]), isNull);
    final malformed = Map<String, dynamic>.from(frames[1]);
    malformed['index'] = 9;
    expect(assembler.add(malformed), isNull);
    expect(assembler.add(frames[1]), isNull);
    final duplicate = {
      'kind': audioMixerFeature,
      'revision': 2,
      'index': 0,
      'parts': 1,
      'available': true,
      'sessions': [app(1).toMap(), app(1).toMap()],
    };
    expect(assembler.add(duplicate), isNull);
    expect(assembler.add(audioMixerFrames([app(2)], 3).single)!.sessions, [
      app(2),
    ]);
  });
}
