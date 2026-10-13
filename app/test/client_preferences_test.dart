import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_remote_control/src/client/preferences/client_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'preferences survive storage round trip and consecutive changes',
    () async {
      final controller = PreferencesController();
      await controller.load();
      final first = controller.update(
        controller.value.copyWith(
          invertScroll: true,
          swapButtons: true,
          themeMode: ThemeMode.light,
          pointerSensitivity: 2.25,
          scrollSensitivity: 0.75,
          mouseUpdateRate: 30,
          multiTouch: false,
          pinchZoom: false,
          doubleTapDrag: true,
          autoReconnect: false,
          automaticDiscovery: false,
          updateServerAddress: false,
          keepConnectionInBackground: true,
          showConnectionErrors: false,
          controlLayout: ControlLayout.drawer,
          orientation: ScreenOrientation.landscape,
          visibleControls: {ControlPage.media, ControlPage.keyboard},
          defaultControl: ControlPage.media,
          hapticFeedback: false,
          fullscreen: true,
          keepScreenAwake: true,
          swipeToOpenMenu: true,
        ),
      );
      final second = controller.update(
        controller.value.copyWith(pointerSensitivity: 3),
      );
      await Future.wait([first, second]);
      final restored = PreferencesController();
      await restored.load();
      expect(restored.value.toJson(), controller.value.toJson());
      expect(restored.value.pointerSensitivity, 3);
      expect(restored.value.defaultControl, ControlPage.media);
      controller.dispose();
      restored.dispose();
    },
  );

  test('invalid stored values fall back to usable bounded defaults', () {
    final p = ClientPreferences.fromJson({
      'visibleControls': [],
      'defaultControl': 'missing',
      'themeMode': 4,
      'pointerSensitivity': 100,
      'scrollSensitivity': -3,
      'mouseUpdateRate': 999,
      'multiTouch': 'yes',
      'fullscreen': null,
    });
    expect(p.visibleControls, ControlPage.values.toSet());
    expect(p.defaultControl, ControlPage.mouse);
    expect(p.pointerSensitivity, 4);
    expect(p.scrollSensitivity, 0.25);
    expect(p.mouseUpdateRate, 60);
    expect(p.multiTouch, true);
    expect(p.themeMode, ThemeMode.dark);
  });

  test(
    'hiding the default picks a visible control and last control remains',
    () {
      final p = const ClientPreferences().copyWith(
        visibleControls: {ControlPage.keyboard},
      );
      expect(p.defaultControl, ControlPage.keyboard);
      expect(p.copyWith(visibleControls: {}).visibleControls, {
        ControlPage.keyboard,
      });
    },
  );
}
