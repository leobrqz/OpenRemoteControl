import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_remote_core/open_remote_core.dart';
import 'package:open_remote_server/src/platform/windows_input.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('open_remote/input');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('reads and validates the native volume result', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'readVolume');
      return {'level': 65, 'muted': true};
    });
    expect(
      await WindowsInput.readVolume(),
      const VolumeState(level: 65, muted: true),
    );

    messenger.setMockMethodCallHandler(channel, (_) async => null);
    expect(await WindowsInput.readVolume(), isNull);

    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {'level': 101, 'muted': false},
    );
    await expectLater(WindowsInput.readVolume(), throwsFormatException);

    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'audio_unavailable');
    });
    await expectLater(
      WindowsInput.readVolume(),
      throwsA(isA<PlatformException>()),
    );
  });

  test('maps mixer sessions and sends bounded per-session commands', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'readAudioSessions') {
        return [
          {
            'id': '1',
            'name': '  Player\n${'x' * 100}  ',
            'device': 'Speakers',
            'level': 42,
            'muted': false,
            'systemSounds': false,
          },
        ];
      }
      return true;
    });
    final sessions = await WindowsInput.readAudioSessions();
    expect(sessions.single.id, '1');
    expect(sessions.single.name.runes.length, 80);
    expect(sessions.single.name, startsWith('Player'));
    expect(sessions.single.name, isNot(contains('\n')));
    expect(await WindowsInput.setAudioSessionLevel('1', 72), isTrue);
    expect(await WindowsInput.setAudioSessionMute('1', true), isTrue);
    expect(calls[1].arguments, {'id': '1', 'level': 72.0});
    expect(calls[2].arguments, {'id': '1', 'muted': true});

    messenger.setMockMethodCallHandler(
      channel,
      (_) async => [
        {
          'id': 'broken',
          'name': '',
          'device': '',
          'level': 2,
          'muted': false,
          'systemSounds': false,
        },
      ],
    );
    await expectLater(WindowsInput.readAudioSessions(), throwsFormatException);
  });
}
