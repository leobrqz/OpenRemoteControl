import 'package:flutter/services.dart';
import 'package:open_remote_core/open_remote_core.dart';

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

  static Future<VolumeState?> readVolume() async {
    final payload = await _channel.invokeMapMethod<Object?, Object?>(
      'readVolume',
    );
    if (payload == null) return null;
    final state = VolumeState.fromMap(payload);
    if (state == null) throw const FormatException('Invalid volume state.');
    return state;
  }

  static Future<List<AudioAppState>> readAudioSessions() async {
    final payload = await _channel.invokeListMethod<Object?>(
      'readAudioSessions',
    );
    if (payload == null || payload.length > maxAudioMixerSessions) {
      throw const FormatException('Invalid audio mixer state.');
    }
    String cleanLabel(Object? value) {
      if (value is! String) throw const FormatException('Invalid audio label.');
      final clean = value.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '').trim();
      return String.fromCharCodes(clean.runes.take(maxAudioMixerLabelRunes));
    }

    final result = <AudioAppState>[];
    final ids = <String>{};
    for (final row in payload) {
      if (row is! Map) throw const FormatException('Invalid audio session.');
      final normalized = Map<Object?, Object?>.from(row);
      normalized['name'] = cleanLabel(row['name']);
      normalized['device'] = cleanLabel(row['device']);
      final session = AudioAppState.fromMap(normalized);
      if (session == null || !ids.add(session.id)) {
        throw const FormatException('Invalid audio session.');
      }
      result.add(session);
    }
    return List.unmodifiable(result);
  }

  static Future<bool> setAudioSessionLevel(String id, int level) async =>
      await _channel.invokeMethod<bool>('setAudioSessionLevel', {
        'id': id,
        'level': level.toDouble(),
      }) ??
      false;

  static Future<bool> setAudioSessionMute(String id, bool muted) async =>
      await _channel.invokeMethod<bool>('setAudioSessionMute', {
        'id': id,
        'muted': muted,
      }) ??
      false;
}
