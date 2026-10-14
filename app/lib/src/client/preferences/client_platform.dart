import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'client_preferences.dart';

class ClientPlatform {
  static const _channel = MethodChannel('open_remote/preferences');
  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> requestBackgroundPermission() async {
    if (!_isAndroid) return false;
    return await _channel.invokeMethod<bool>('requestNotificationPermission') ??
        false;
  }

  static Future<void> setBackgroundConnection(
    bool enabled,
    String? address,
  ) async {
    if (!_isAndroid) return;
    await _channel.invokeMethod<void>('setBackgroundConnection', {
      'enabled': enabled,
      'address': address ?? 'PC',
    });
  }

  static Future<void> setLanguage(String language) async {
    if (!_isAndroid) return;
    await _channel.invokeMethod<void>('setLanguage', {'language': language});
  }

  static Future<void> applyDisplay(
    ClientPreferences preferences, {
    required bool controlling,
  }) async {
    await SystemChrome.setPreferredOrientations(
      switch (preferences.orientation) {
        ScreenOrientation.automatic => [],
        ScreenOrientation.portrait => [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ],
        ScreenOrientation.landscape => [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
      },
    );
    if (!_isAndroid) return;
    await _channel.invokeMethod<void>('setDisplayPreferences', {
      'fullscreen': preferences.fullscreen,
      'keepScreenAwake': preferences.keepScreenAwake && controlling,
    });
  }
}
