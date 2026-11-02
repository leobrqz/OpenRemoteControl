import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_remote_core/open_remote_core.dart';
import 'package:open_remote_server/src/host/audio_mixer_commands.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('open_remote/input');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return false; // An expired session must not disconnect the client.
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'valid commands reach the intended session; stale sessions are harmless',
    () async {
      await AudioMixerCommands.apply({
        'kind': audioSessionLevelCommand,
        'id': '12',
        'level': 0,
      });
      await AudioMixerCommands.apply({
        'kind': audioSessionLevelCommand,
        'id': '12',
        'level': 100,
      });
      await AudioMixerCommands.apply({
        'kind': audioSessionMuteCommand,
        'id': '12',
        'muted': true,
      });
      expect(calls.map((call) => call.method), [
        'setAudioSessionLevel',
        'setAudioSessionLevel',
        'setAudioSessionMute',
      ]);
      expect(calls.last.arguments, {'id': '12', 'muted': true});
    },
  );

  test(
    'rejects invalid identifiers, values and commands before reaching Windows',
    () async {
      for (final command in [
        {'kind': audioSessionLevelCommand, 'id': '0', 'level': 50},
        {'kind': audioSessionLevelCommand, 'id': 'bad', 'level': 50},
        {'kind': audioSessionLevelCommand, 'id': '1', 'level': -1},
        {'kind': audioSessionLevelCommand, 'id': '1', 'level': 101},
        {'kind': audioSessionLevelCommand, 'id': '1', 'level': 50.0},
        {'kind': audioSessionMuteCommand, 'id': '1', 'muted': 'true'},
        {'kind': 'unknown', 'id': '1'},
      ]) {
        await expectLater(
          AudioMixerCommands.apply(command),
          throwsFormatException,
        );
      }
      expect(calls, isEmpty);
    },
  );
}
