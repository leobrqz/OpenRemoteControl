import 'dart:async';

import 'package:flutter/material.dart';

import 'android_update_controller.dart';

const androidUpdateNotification = <String, String>{
  'title': 'Open Remote Control',
  'downloading': 'Baixando atualização',
  'validating': 'Validando atualização',
  'ready': 'Atualização pronta para instalar',
  'cancel': 'Cancelar',
  'channelName': 'Atualizações do aplicativo',
};

String _status(
  AndroidUpdateController controller,
) => switch (controller.state.name) {
  'checking' => 'Verificando atualizações…',
  'upToDate' => 'Você está na versão mais recente para este dispositivo.',
  'available' => 'Atualização disponível.',
  'deferred' => 'Atualização adiada até abrir o aplicativo novamente.',
  'downloading' => 'Baixando atualização…',
  'validating' => 'Validando o APK…',
  'ready' => 'APK validado. Pronto para instalar.',
  'installing' => 'Confirme a atualização no instalador do Android.',
  'cancelled' => 'Download cancelado.',
  'installationCancelled' =>
    'Instalação cancelada. Você pode tentar novamente.',
  'permissionRequired' =>
    'Para instalar a atualização, permita que o Open Remote Control instale aplicativos na configuração do Android. Depois, volte aqui para continuar.',
  'failed' => _error(controller.errorCode),
  'idle' =>
    controller.errorCode == null
        ? 'Verifique se há uma nova versão do aplicativo.'
        : _error(controller.errorCode),
  _ => 'Verifique se há uma nova versão do aplicativo.',
};

String _error(String? code) => switch (code) {
  'network' => 'Falha de conexão. Verifique a internet e tente novamente.',
  'unavailable' =>
    'O arquivo da atualização não está disponível. Verifique novamente.',
  'storage' => 'Sem espaço suficiente. Libere espaço e tente novamente.',
  'integrity' => 'O APK está incompleto ou corrompido. Baixe novamente.',
  'identity' =>
    'O APK não pertence a este aplicativo. A instalação foi bloqueada.',
  'signature' =>
    'A assinatura do APK não corresponde à versão instalada. A instalação foi bloqueada.',
  'incompatible' => 'O APK não é compatível com este dispositivo.',
  'invalidPackage' => 'Não foi possível validar o APK. Baixe novamente.',
  'permission' =>
    'A instalação não foi autorizada. Você pode continuar usando o aplicativo.',
  'installer' => 'Não foi possível iniciar a instalação. Tente novamente.',
  'interrupted' =>
    'O download foi interrompido. Baixe novamente para continuar.',
  'busy' => 'Já existe uma atualização em andamento.',
  _ => 'Não foi possível atualizar. Tente novamente.',
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
                'Atualizações',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text('Versão instalada: ${controller.currentVersion ?? '—'}'),
              if (candidate != null) ...[
                Text('Versão disponível: ${candidate.versionName}'),
                Text(
                  'Download: ${(candidate.size / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} MB',
                ),
              ],
              const SizedBox(height: 12),
              Text(_status(controller)),
              if (candidate != null && candidate.notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Notas da versão'),
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
                      'Atualizar',
                      () => controller.approveDownload(
                        notification: androidUpdateNotification,
                      ),
                    ),
                    TextButton(
                      onPressed: controller.defer,
                      child: const Text('Agora não'),
                    ),
                  ],
                  if (downloading) _button('Cancelar', controller.cancel),
                  if (state == 'permissionRequired')
                    _button(
                      'Permitir instalação',
                      controller.openInstallPermission,
                    ),
                  if (state == 'ready' || state == 'installationCancelled')
                    _button('Instalar atualização', controller.install),
                  if (state == 'ready' ||
                      state == 'permissionRequired' ||
                      state == 'installationCancelled')
                    TextButton(
                      onPressed: () => unawaited(controller.cancel()),
                      child: const Text('Cancelar atualização'),
                    ),
                  if (!controller.busy &&
                      !downloading &&
                      state != 'ready' &&
                      state != 'permissionRequired' &&
                      state != 'installationCancelled')
                    _button(
                      state == 'failed'
                          ? 'Tentar novamente'
                          : 'Verificar atualizações',
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
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    downloading
                        ? _status(controller)
                        : ready
                        ? 'Atualização pronta para instalar'
                        : 'Atualização ${controller.candidate?.versionName ?? ''} disponível',
                  ),
                ),
                TextButton(
                  onPressed: onDetails,
                  child: const Text('Ver atualização'),
                ),
                if (downloading)
                  TextButton(
                    onPressed: () => unawaited(controller.cancel()),
                    child: const Text('Cancelar'),
                  )
                else if (!ready)
                  TextButton(
                    onPressed: controller.defer,
                    child: const Text('Agora não'),
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
