import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:open_remote_control/l10n/app_localizations.dart';

import '../preferences/client_preferences.dart';
import 'remote_actions.dart';

class MouseControl extends StatefulWidget {
  const MouseControl({
    super.key,
    required this.actions,
    required this.preferences,
    required this.active,
  });
  final RemoteActions actions;
  final ClientPreferences preferences;
  final bool active;
  @override
  State<MouseControl> createState() => _MouseControlState();
}

class _MouseControlState extends State<MouseControl> {
  bool _dragMode = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Expanded(
                child: MouseTouchpad(
                  actions: widget.actions,
                  preferences: widget.preferences,
                  active: widget.active,
                  dragMode: _dragMode,
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(l10n.drag),
                value: _dragMode,
                onChanged: (enabled) => setState(() => _dragMode = enabled),
              ),
              Row(
                children: [
                  for (final entry in {
                    'left': l10n.leftClick,
                    'middle': l10n.middleClick,
                    'right': l10n.rightClick,
                  }.entries)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: FilledButton.tonal(
                          onPressed: widget.active
                              ? () => widget.actions.click(entry.key)
                              : null,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 12,
                            ),
                          ),
                          child: Text(entry.value, textAlign: TextAlign.center),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.active
                          ? () => widget.actions.scroll(120)
                          : null,
                      icon: const Icon(Icons.keyboard_arrow_up),
                      label: Text(l10n.scroll),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.active
                          ? () => widget.actions.scroll(-120)
                          : null,
                      icon: const Icon(Icons.keyboard_arrow_down),
                      label: Text(l10n.scroll),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
        if (constraints.maxHeight < 360) {
          return SingleChildScrollView(
            child: SizedBox(height: 420, child: content),
          );
        }
        return content;
      },
    );
  }
}

enum _TwoFingerGesture { undecided, scroll, zoom }

class MouseTouchpad extends StatefulWidget {
  const MouseTouchpad({
    super.key,
    required this.actions,
    required this.preferences,
    required this.active,
    this.dragMode = false,
  });
  final RemoteActions actions;
  final ClientPreferences preferences;
  final bool active, dragMode;
  @override
  State<MouseTouchpad> createState() => _MouseTouchpadState();
}

class _MouseTouchpadState extends State<MouseTouchpad> {
  final Map<int, Offset> _pointers = {};
  int _maxPointers = 0;
  Duration _startedAt = Duration.zero;
  Duration? _lastTapAt;
  Offset? _lastTapPosition;
  Offset _firstPosition = Offset.zero,
      _startCenter = Offset.zero,
      _previousCenter = Offset.zero;
  double _travel = 0,
      _startDistance = 0,
      _previousDistance = 0,
      _zoomRemainder = 0;
  _TwoFingerGesture _gesture = _TwoFingerGesture.undecided;
  String? _heldButton;
  bool _cancelled = false;

  @override
  void didUpdateWidget(MouseTouchpad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active ||
        oldWidget.dragMode != widget.dragMode ||
        oldWidget.preferences != widget.preferences) {
      _cancel();
    }
  }

  void _release() {
    final button = _heldButton;
    _heldButton = null;
    if (button != null) widget.actions.releaseButton(button);
  }

  void _cancel() {
    _release();
    _pointers.clear();
    _cancelled = true;
    _lastTapAt = null;
    widget.actions.flushMotion();
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  void _down(PointerDownEvent event) {
    if (!widget.active) return;
    if (_pointers.isEmpty) {
      _maxPointers = 0;
      _travel = 0;
      _cancelled = false;
      _gesture = _TwoFingerGesture.undecided;
      _startedAt = event.timeStamp;
      _firstPosition = event.localPosition;
      _zoomRemainder = 0;
      final doubleTap =
          widget.preferences.doubleTapDrag &&
          _lastTapAt != null &&
          event.timeStamp - _lastTapAt! <= const Duration(milliseconds: 300) &&
          (event.localPosition - _lastTapPosition!).distance < 30;
      if (widget.dragMode || doubleTap) {
        _heldButton = widget.actions.holdPrimary();
      }
      _lastTapAt = null;
    }
    _pointers[event.pointer] = event.localPosition;
    _maxPointers = math.max(_maxPointers, _pointers.length);
    if (_pointers.length == 2) {
      _release();
      widget.actions.flushMotion();
      final points = _pointers.values.toList();
      _startCenter = _previousCenter = (points[0] + points[1]) / 2;
      _startDistance = _previousDistance = (points[0] - points[1]).distance;
    } else if (_pointers.length > 2) {
      _release();
      _cancelled = true;
    }
  }

  void _move(PointerMoveEvent event) {
    final previous = _pointers[event.pointer];
    if (previous == null || !widget.active || _cancelled) return;
    _pointers[event.pointer] = event.localPosition;
    final delta = event.localPosition - previous;
    _travel += delta.distance;
    if (_pointers.length == 1 && _maxPointers == 1) {
      widget.actions.move(delta.dx, delta.dy);
      return;
    }
    if (_pointers.length != 2 || !widget.preferences.multiTouch) return;
    final points = _pointers.values.toList();
    final center = (points[0] + points[1]) / 2;
    final distance = (points[0] - points[1]).distance;
    if (_gesture == _TwoFingerGesture.undecided) {
      if (widget.preferences.pinchZoom &&
          _startDistance > 10 &&
          distance > 10 &&
          (math.log(distance / _startDistance)).abs() > 0.065) {
        _gesture = _TwoFingerGesture.zoom;
      } else if ((center - _startCenter).distance > 6) {
        _gesture = _TwoFingerGesture.scroll;
      }
    }
    if (_gesture == _TwoFingerGesture.scroll) {
      widget.actions.scroll(-(center - _previousCenter).dy * 6);
      _previousCenter = center;
    } else if (_gesture == _TwoFingerGesture.zoom &&
        _previousDistance > 10 &&
        distance > 10) {
      _zoomRemainder += math.log(distance / _previousDistance) / math.log(1.12);
      final notches = _zoomRemainder.truncate();
      if (notches != 0) {
        widget.actions.zoom(notches * 120);
        _zoomRemainder -= notches;
      }
      _previousDistance = distance;
    }
  }

  void _up(PointerEvent event, {bool cancel = false}) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers.remove(event.pointer);
    if (cancel) {
      _cancelled = true;
      _release();
    }
    if (_pointers.isNotEmpty) return;
    widget.actions.flushMotion();
    final wasDragging = _heldButton != null;
    _release();
    final tap =
        !_cancelled &&
        !wasDragging &&
        _travel < 8 &&
        event.timeStamp - _startedAt < const Duration(milliseconds: 300);
    if (tap && _maxPointers == 1) {
      widget.actions.click('left');
      _lastTapAt = event.timeStamp;
      _lastTapPosition = _firstPosition;
    } else if (tap && _maxPointers == 2 && widget.preferences.multiTouch) {
      widget.actions.click('right');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: l10n.touchpad,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _up,
        onPointerCancel: (event) => _up(event, cancel: true),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            border: Border.all(color: colors.outlineVariant),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.touch_app_outlined, color: colors.primary, size: 32),
                const SizedBox(height: 8),
                Text(
                  widget.dragMode ? l10n.dragToSelect : l10n.swipeToMove,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.tapToClick,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
