import 'dart:async';

import 'package:flutter/material.dart';
import 'package:open_remote_control/l10n/app_localizations.dart';
import 'package:open_remote_core/open_remote_core.dart';

import 'remote_actions.dart';

class AudioMixerControl extends StatelessWidget {
  const AudioMixerControl({
    super.key,
    required this.actions,
    required this.active,
    required this.sessions,
  });

  final RemoteActions actions;
  final bool active;
  final List<AudioAppState>? sessions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final apps = sessions;
    return ExpansionTile(
      title: Text(l10n.audioMixer),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: [
        if (apps == null || apps.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              apps == null ? l10n.volumeUnavailable : l10n.noAudioSessions,
            ),
          )
        else
          for (final session in apps)
            _AudioSessionControl(
              key: ValueKey(session.id),
              session: session,
              actions: actions,
              active: active,
            ),
      ],
    );
  }
}

class _AudioSessionControl extends StatefulWidget {
  const _AudioSessionControl({
    super.key,
    required this.session,
    required this.actions,
    required this.active,
  });

  final AudioAppState session;
  final RemoteActions actions;
  final bool active;

  @override
  State<_AudioSessionControl> createState() => _AudioSessionControlState();
}

class _AudioSessionControlState extends State<_AudioSessionControl> {
  int? _dragLevel;
  bool _dragging = false;
  Timer? _settleTimer;

  @override
  void didUpdateWidget(covariant _AudioSessionControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active) {
      _dragging = false;
      _dragLevel = null;
      _settleTimer?.cancel();
    } else if (!_dragging && widget.session.level == _dragLevel) {
      _dragLevel = null;
      _settleTimer?.cancel();
    }
  }

  void _settle() {
    _settleTimer?.cancel();
    _settleTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && !_dragging) setState(() => _dragLevel = null);
    });
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final session = widget.session;
    final name = session.systemSounds
        ? l10n.systemSounds
        : session.name.isEmpty
        ? l10n.audioApplication
        : session.name;
    final level = _dragLevel ?? session.level;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          ListTile(
            dense: true,
            title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: session.device.isEmpty
                ? null
                : Text(
                    session.device,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            trailing: IconButton(
              tooltip: session.muted ? l10n.unmute : l10n.mute,
              onPressed: widget.active
                  ? () => widget.actions.audioMute(session.id, !session.muted)
                  : null,
              icon: Icon(
                session.muted
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  label: '$name ${l10n.volume}',
                  child: Slider(
                    value: level.toDouble(),
                    min: 0,
                    max: 100,
                    semanticFormatterCallback: (value) => '${value.round()}%',
                    onChangeStart: widget.active
                        ? (_) {
                            _dragging = true;
                            _settleTimer?.cancel();
                          }
                        : null,
                    onChanged: widget.active
                        ? (value) {
                            final next = value.round();
                            setState(() => _dragLevel = next);
                            widget.actions.audioLevel(session.id, next);
                            if (!_dragging) _settle();
                          }
                        : null,
                    onChangeEnd: widget.active
                        ? (_) {
                            _dragging = false;
                            widget.actions.flushAudioLevels();
                            _settle();
                          }
                        : null,
                  ),
                ),
              ),
              SizedBox(width: 48, child: Text('$level%')),
            ],
          ),
        ],
      ),
    );
  }
}
