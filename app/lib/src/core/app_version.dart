import 'package:package_info_plus/package_info_plus.dart';

class AppVersion {
  AppVersion._();

  static PackageInfo? _info;

  static String get version => _info?.version ?? 'Development';
  static String get buildNumber => _info?.buildNumber ?? '0';
  static String get label => '$version+$buildNumber';

  static Future<void> load() async {
    _info = await PackageInfo.fromPlatform();
  }
}
