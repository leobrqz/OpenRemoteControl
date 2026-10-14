import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../l10n/app_localizations.dart';

import 'android_update_controller.dart';

const androidUpdateNotification = <String, String>{
  'title': 'Open Remote Control',
  'downloading': 'Downloading update',
  'validating': 'Validating update',
  'ready': 'Update ready to install',
  'cancel': 'Cancel',
  'channelName': 'App updates',
};

Map<String, String> androidUpdateNotificationFor(AppLocalizations l10n) => {
  'title': 'Open Remote Control',
  'downloading': l10n.notificationDownloading,
  'validating': l10n.notificationValidating,
  'ready': l10n.notificationReady,
  'cancel': l10n.cancel,
  'channelName': l10n.notificationChannel,
};

String _status(AppLocalizations l10n, AndroidUpdateController controller) =>
    switch (controller.state.name) {
      'checking' => l10n.updateChecking,
      'upToDate' => l10n.updateUpToDate,
      'available' => l10n.updateAvailable,
      'deferred' => l10n.updateDeferred,
      'downloading' => l10n.updateDownloading,
      'validating' => l10n.updateValidating,
      'ready' => l10n.updateReady,
      'installing' => l10n.updateInstalling,
      'cancelled' => l10n.updateCancelled,
      'installationCancelled' => l10n.updateInstallationCancelled,
      'permissionRequired' => l10n.updatePermissionRequired,
      'failed' => _error(l10n, controller.errorCode),
      'idle' =>
        controller.errorCode == null
            ? l10n.checkForUpdates
            : _error(l10n, controller.errorCode),
      _ => l10n.checkForUpdates,
    };

String _error(AppLocalizations l10n, String? code) => switch (code) {
  'network' => l10n.updateNetworkError,
  'unavailable' => l10n.updateUnavailableError,
  'storage' => l10n.updateStorageError,
  'integrity' => l10n.updateIntegrityError,
  'identity' => l10n.updateIdentityError,
  'signature' => l10n.updateSignatureError,
  'incompatible' => l10n.updateIncompatibleError,
  'invalidPackage' => l10n.updateInvalidPackageError,
  'permission' => l10n.updatePermissionError,
  'installer' => l10n.updateInstallerError,
  'interrupted' => l10n.updateInterruptedError,
  'busy' => l10n.updateBusyError,
  _ => l10n.updateGenericError,
};

class AndroidUpdateCard extends StatelessWidget {
  const AndroidUpdateCard({super.key, required this.controller});
  final AndroidUpdateController controller;

  Widget _button(String label, Future<void> Function() action) =>
      FilledButton(onPressed: () => unawaited(action()), child: Text(label));

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final l10n = AppLocalizations.of(context)!;
      final candidate = controller.candidate;
      final state = controller.state.name;
      final downloading = state == 'downloading' || state == 'validating';
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.updateTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(l10n.installedVersion(controller.currentVersion ?? '—')),
              if (candidate != null) ...[
                Text(l10n.availableVersion(candidate.versionName)),
                Text(
                  l10n.downloadSize(
                    (NumberFormat.decimalPattern(l10n.localeName)
                          ..minimumFractionDigits = 1
                          ..maximumFractionDigits = 1)
                        .format(candidate.size / (1024 * 1024)),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(_status(l10n, controller)),
              if (candidate != null && candidate.notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(l10n.releaseNotes),
                const SizedBox(height: 4),
                SelectableText(candidate.notes),
              ],
              if (downloading) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: state == 'validating' ? null : controller.progress,
                ),
                if (state == 'downloading')
                  Text('${(controller.progress * 100).round()}%'),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (controller.available) ...[
                    _button(
                      l10n.updateNow,
                      () => controller.approveDownload(
                        notification: androidUpdateNotificationFor(l10n),
                      ),
                    ),
                    TextButton(
                      onPressed: controller.defer,
                      child: Text(l10n.notNow),
                    ),
                  ],
                  if (downloading) _button(l10n.cancel, controller.cancel),
                  if (state == 'permissionRequired')
                    _button(
                      l10n.allowInstall,
                      controller.openInstallPermission,
                    ),
                  if (state == 'ready' || state == 'installationCancelled')
                    _button(l10n.installUpdate, controller.install),
                  if (state == 'ready' ||
                      state == 'permissionRequired' ||
                      state == 'installationCancelled')
                    TextButton(
                      onPressed: () => unawaited(controller.cancel()),
                      child: Text(l10n.cancelUpdate),
                    ),
                  if (!controller.busy &&
                      !downloading &&
                      state != 'ready' &&
                      state != 'permissionRequired' &&
                      state != 'installationCancelled')
                    _button(
                      state == 'failed' ? l10n.tryAgain : l10n.checkForUpdates,
                      () => controller.check(manual: true),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class AndroidUpdateNotice extends StatelessWidget {
  const AndroidUpdateNotice({
    super.key,
    required this.controller,
    required this.onDetails,
  });
  final AndroidUpdateController controller;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = controller.state.name;
    final downloading = state == 'downloading' || state == 'validating';
    final ready =
        state == 'ready' ||
        state == 'permissionRequired' ||
        state == 'installationCancelled';
    if (!downloading && !ready && !controller.showReminder) {
      return const SizedBox.shrink();
    }
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              downloading
                  ? _status(l10n, controller)
                  : ready
                  ? l10n.updateReady
                  : l10n.updateAvailableNotice(
                      controller.candidate?.versionName ?? '',
                    ),
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(onPressed: onDetails, child: Text(l10n.viewUpdate)),
                if (downloading)
                  TextButton(
                    onPressed: () => unawaited(controller.cancel()),
                    child: Text(l10n.cancel),
                  )
                else if (!ready)
                  TextButton(
                    onPressed: controller.defer,
                    child: Text(l10n.notNow),
                  ),
              ],
            ),
            if (downloading)
              LinearProgressIndicator(
                value: state == 'validating' ? null : controller.progress,
              ),
          ],
        ),
      ),
    );
  }
}
