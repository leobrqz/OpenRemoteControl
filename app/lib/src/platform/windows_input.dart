import 'package:flutter/services.dart';

class WindowsInput {
  WindowsInput._();

  static const MethodChannel _channel = MethodChannel('open_remote/input');

  static Future<void> moveMouse(double dx, double dy) =>
      _channel.invokeMethod<void>('mouseMove', {'dx': dx, 'dy': dy});

  static Future<void> mouseButton(String button, bool pressed) =>
      _channel.invokeMethod<void>('mouseButton', {
        'button': button,
        'pressed': pressed,
      });

  static Future<void> scroll(int delta) =>
      _channel.invokeMethod<void>('mouseScroll', {'delta': delta.toDouble()});

  static Future<void> zoom(int delta, {bool controlHeld = false}) =>
      _channel.invokeMethod<void>('mouseZoom', {
        'delta': delta.toDouble(),
        'controlHeld': controlHeld,
      });

  static Future<void> typeText(String text) =>
      _channel.invokeMethod<void>('typeText', {'text': text});

  static Future<void> pressKey(String key) =>
      _channel.invokeMethod<void>('pressKey', {'key': key});

  static Future<void> keyState(String key, bool pressed) =>
      _channel.invokeMethod<void>('keyState', {'key': key, 'pressed': pressed});

  static Future<void> media(String command) =>
      _channel.invokeMethod<void>('media', {'command': command});
}
