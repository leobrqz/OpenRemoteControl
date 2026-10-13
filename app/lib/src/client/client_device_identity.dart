import 'package:flutter/services.dart';

/// Optional, user-visible Android identity shared with the Windows host.
class ClientDeviceIdentity {
  const ClientDeviceIdentity({
    required this.name,
    this.model,
    this.androidVersion,
  });

  static const _channel = MethodChannel('open_remote/device_identity');
  static const fallback = ClientDeviceIdentity(name: 'Android');

  final String name;
  final String? model;
  final String? androidVersion;

  /// Reads fresh values for each connection; metadata failure is non-fatal.
  static Future<ClientDeviceIdentity> load({MethodChannel? channel}) async {
    try {
      final result = await (channel ?? _channel)
          .invokeMapMethod<Object?, Object?>('getDeviceIdentity');
      if (result == null) return fallback;
      return ClientDeviceIdentity(
        name: _clean(result['clientName']) ?? fallback.name,
        model: _clean(result['clientModel']),
        androidVersion: _clean(result['clientAndroidVersion']),
      );
    } catch (_) {
      return fallback;
    }
  }

  Map<String, Object?> get authFields => {
    // Missing platform details must not replace a saved phone name on resume.
    if (name != fallback.name || model != null || androidVersion != null)
      'clientName': name,
    if (model != null) 'clientModel': model,
    if (androidVersion != null) 'clientAndroidVersion': androidVersion,
  };

  static String? _clean(Object? value) {
    if (value is! String) return null;
    final cleaned = value
        .replaceAll(RegExp(r'[\x00-\x1f\x7f-\x9f]'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) return null;
    return cleaned.length <= 64 ? cleaned : cleaned.substring(0, 64).trim();
  }
}
