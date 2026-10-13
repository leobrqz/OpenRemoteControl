import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutService {
  const AboutService();

  Future<String> installedVersion() async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version}+${info.buildNumber}';
  }

  Future<bool> openExternal(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}
