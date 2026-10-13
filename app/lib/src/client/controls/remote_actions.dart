import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../preferences/client_preferences.dart';

/// Transforms input preferences before the service serializes secure frames.
class RemoteActions {
  RemoteActions({
    required this.send,
    required this.preferences,
    required this.connected,
    this.onError,
    VoidCallback? vibrate,
  }) : _vibrate = vibrate ?? (() => unawaited(HapticFeedback.selectionClick()));

  final Future<void> Function(Map<String, Object?>) send;
  final ClientPreferences Function() preferences;
  final bool Function() connected;
  final void Function(Object)? onError;
  final VoidCallback _vibrate;
  final Set<String> _heldButtons = {}, _heldModifiers = {};
  Timer? _motionTimer;
  double _dx = 0, _dy = 0, _scroll = 0;
  bool _disposed = false;

  void command(Map<String, Object?> command, {bool feedback = true}) {
    if (_disposed || !connected()) return;
    if (feedback && preferences().hapticFeedback) _vibrate();
    unawaited(
      send(command).catchError((Object error) {
        onError?.call(error);
      }),
    );
  }

  String _button(String button) => !preferences().swapButtons
      ? button
      : switch (button) {
          'left' => 'right',
          'right' => 'left',
          _ => button,
        };

  void click(String button) {
    flushMotion();
    final mapped = _button(button);
    command({'kind': 'mouse.button', 'button': mapped, 'pressed': true});
    command({
      'kind': 'mouse.button',
      'button': mapped,
      'pressed': false,
    }, feedback: false);
  }

  String holdPrimary() {
    final button = _button('left');
    _heldButtons.add(button);
    command({'kind': 'mouse.button', 'button': button, 'pressed': true});
    return button;
  }

  void releaseButton(String button) {
    flushMotion();
    if (_heldButtons.remove(button)) {
      command({
        'kind': 'mouse.button',
        'button': button,
        'pressed': false,
      }, feedback: false);
    }
  }

  void move(double dx, double dy) {
    if (!connected() || !dx.isFinite || !dy.isFinite) return;
    final p = preferences();
    _dx += dx * p.pointerSensitivity;
    _dy += dy * p.pointerSensitivity;
    if (!p.limitMouseUpdates) {
      flushMotion();
      return;
    }
    _motionTimer ??= Timer(
      Duration(microseconds: (1000000 / p.mouseUpdateRate).round()),
      flushMotion,
    );
  }

  void flushMotion() {
    _motionTimer?.cancel();
    _motionTimer = null;
    var dx = _dx.truncate(), dy = _dy.truncate();
    _dx -= dx;
    _dy -= dy;
    if (!connected()) {
      _dx = _dy = 0;
      return;
    }
    while (dx != 0 || dy != 0) {
      final x = dx.clamp(-500, 500), y = dy.clamp(-500, 500);
      command({
        'kind': 'mouse.move',
        'dx': x.toDouble(),
        'dy': y.toDouble(),
      }, feedback: false);
      dx -= x;
      dy -= y;
    }
  }

  void scroll(double delta) {
    if (!connected() || !delta.isFinite) return;
    final p = preferences();
    _scroll += delta * p.scrollSensitivity * (p.invertScroll ? -1 : 1);
    var steps = _scroll.truncate();
    _scroll -= steps;
    while (steps != 0) {
      final chunk = steps.clamp(-1200, 1200);
      command({'kind': 'mouse.scroll', 'delta': chunk}, feedback: false);
      steps -= chunk;
    }
  }

  void zoom(int direction) => command({
    'kind': 'mouse.zoom',
    'delta': math.min(1200, direction.abs()) * direction.sign,
  }, feedback: false);
  void media(String action) =>
      command({'kind': 'media.command', 'action': action});
  void key(String key) => command({'kind': 'keyboard.key', 'key': key});
  void text(String text) {
    // Split on rune boundaries so Unicode and the server's 512-code-unit limit survive.
    var chunk = StringBuffer(), length = 0;
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      if (length + char.length > 512) {
        command({'kind': 'keyboard.text', 'text': chunk.toString()});
        chunk = StringBuffer();
        length = 0;
      }
      chunk.write(char);
      length += char.length;
    }
    if (length > 0) {
      command({'kind': 'keyboard.text', 'text': chunk.toString()});
    }
  }

  void modifier(String key, bool pressed) {
    if (pressed) {
      _heldModifiers.add(key);
    } else {
      _heldModifiers.remove(key);
    }
    command({'kind': 'keyboard.modifier', 'key': key, 'pressed': pressed});
  }

  void releaseAll() {
    flushMotion();
    for (final button in _heldButtons.toList()) {
      releaseButton(button);
    }
    for (final key in _heldModifiers.toList()) {
      modifier(key, false);
    }
    _dx = _dy = _scroll = 0;
  }

  void dispose() {
    releaseAll();
    _disposed = true;
    _motionTimer?.cancel();
  }
}
