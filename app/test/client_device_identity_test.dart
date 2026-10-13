import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_remote_control/src/client/client_device_identity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('open_remote/test_device_identity');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'loads and sanitizes Android identity from the platform channel',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'getDeviceIdentity');
            return <String, Object?>{
              'clientName': '  Pixel\n9 Pro  ',
              'clientModel': 'Pixel 9 Pro',
              'clientAndroidVersion': ' 16 ',
            };
          });

      final identity = await ClientDeviceIdentity.load(channel: channel);

      expect(identity.name, 'Pixel 9 Pro');
      expect(identity.model, 'Pixel 9 Pro');
      expect(identity.androidVersion, '16');
      expect(identity.authFields, {
        'clientName': 'Pixel 9 Pro',
        'clientModel': 'Pixel 9 Pro',
        'clientAndroidVersion': '16',
      });
    },
  );

  test(
    'uses a generic identity when platform metadata is unavailable',
    () async {
      final identity = await ClientDeviceIdentity.load(channel: channel);

      expect(identity.name, 'Android');
      expect(identity.authFields, isEmpty);
    },
  );

  test(
    'bounds unusually long metadata and omits blank optional values',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            return <String, Object?>{
              'clientName': 'N' * 100,
              'clientModel': '   ',
              'clientAndroidVersion': 16,
            };
          });

      final identity = await ClientDeviceIdentity.load(channel: channel);

      expect(identity.name, 'N' * 64);
      expect(identity.model, isNull);
      expect(identity.androidVersion, isNull);
      expect(identity.authFields, {'clientName': 'N' * 64});
    },
  );
}
