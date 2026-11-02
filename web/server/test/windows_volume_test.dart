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
}
