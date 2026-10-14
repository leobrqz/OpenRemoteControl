import 'package:flutter/material.dart';
import 'package:open_remote_control/l10n/app_localizations.dart';

import 'remote_actions.dart';

class MediaControl extends StatelessWidget {
  const MediaControl({super.key, required this.actions, required this.active});
  final RemoteActions actions;
  final bool active;

  Widget _button(
    BuildContext context,
    IconData icon,
    String label,
    String action, {
    bool prominent = false,
  }) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton.filledTonal(
        tooltip: label,
        onPressed: active ? () => actions.media(action) : null,
        icon: Icon(icon),
        iconSize: prominent ? 38 : 28,
        padding: EdgeInsets.all(prominent ? 20 : 16),
        style: prominent
            ? IconButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              )
            : null,
      ),
      const SizedBox(height: 8),
      Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, size) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: size.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.volume,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _button(
                            context,
                            Icons.volume_down_rounded,
                            l10n.decreaseVolume,
                            'volumeDown',
                          ),
                        ),
                        Expanded(
                          child: _button(
                            context,
                            Icons.volume_off_rounded,
                            l10n.mute,
                            'volumeMute',
                          ),
                        ),
                        Expanded(
                          child: _button(
                            context,
                            Icons.volume_up_rounded,
                            l10n.increaseVolume,
                            'volumeUp',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: _button(
                            context,
                            Icons.skip_previous_rounded,
                            l10n.previousTrack,
                            'previousTrack',
                          ),
                        ),
                        Expanded(
                          child: _button(
                            context,
                            Icons.play_arrow_rounded,
                            l10n.playPause,
                            'playPause',
                            prominent: true,
                          ),
                        ),
                        Expanded(
                          child: _button(
                            context,
                            Icons.skip_next_rounded,
                            l10n.nextTrack,
                            'nextTrack',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: active ? () => actions.media('stop') : null,
                      icon: const Icon(Icons.stop_rounded),
                      label: Text(l10n.stop),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
