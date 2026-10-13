import 'package:flutter_test/flutter_test.dart';
import 'package:open_remote_control/src/core/app_version.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  test('reads version and build from installed package metadata', () async {
    PackageInfo.setMockInitialValues(
      appName: 'Open Remote Control',
      packageName: 'org.openremotecontrol.open_remote_control',
      version: '0.1.0',
      buildNumber: '2',
      buildSignature: '',
    );
    await AppVersion.load();

    expect(AppVersion.version, '0.1.0');
    expect(AppVersion.buildNumber, '2');
    expect(AppVersion.label, '0.1.0+2');
  });
}
