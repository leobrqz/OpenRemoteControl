import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart' hide MenuItem;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../core/diagnostic_log.dart';
import 'host_service.dart';

class HostScreen extends StatefulWidget {
  const HostScreen({super.key});

  @override
  State<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends State<HostScreen>
    with TrayListener, WindowListener {
  final RemoteHostService _service = RemoteHostService();
  bool _working = false;
  bool _trayReady = false;
  bool _allowClose = false;
  Timer? _expiryTimer;
  Timer? _trayClickTimer;
  DateTime? _lastTrayClick;

  @override
  void initState() {
    super.initState();
    _service.addListener(_refresh);
    trayManager.addListener(this);
    windowManager.addListener(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initializeBackgroundServer());
    });
    _expiryTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && _service.isRunning) setState(() {});
    });
  }

  @override
  void dispose() {
    _service.removeListener(_refresh);
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    _expiryTimer?.cancel();
    _trayClickTimer?.cancel();
    _service.dispose();
    super.dispose();
  }

  Future<void> _initializeBackgroundServer() async {
    try {
      await windowManager.setPreventClose(true);
      try {
        await _service.startDashboard();
      } catch (error, stackTrace) {
        await DiagnosticLog.record(
          'Windows',
          'Painel localhost indisponível; o servidor de controle continuará iniciando.',
          error: error,
          stackTrace: stackTrace,
        );
      }
      try {
        await trayManager.setIcon('assets/tray_icon.ico');
        await trayManager.setToolTip('Open Remote Control');
        await trayManager.setContextMenu(
          Menu(
            items: [
              MenuItem(key: 'open_dashboard', label: 'Abrir painel local'),
              MenuItem(key: 'show_window', label: 'Mostrar aplicativo'),
              MenuItem.separator(),
              MenuItem(key: 'exit', label: 'Sair'),
            ],
          ),
        );
        _trayReady = true;
      } catch (error, stackTrace) {
        await DiagnosticLog.record(
          'Windows',
          'Ícone da bandeja indisponível.',
          error: error,
          stackTrace: stackTrace,
        );
      }
      await _service.start();
      if (_service.isRunning && _trayReady) {
        await _hideWindow();
      } else {
        await _showWindow();
      }
    } catch (error, stackTrace) {
      await DiagnosticLog.record(
        'Windows',
        'Falha ao preparar o servidor em segundo plano.',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        await _showWindow();
        _showMessage(_service.lastError ?? error.toString());
      }
    }
  }

  Future<void> _showWindow() async {
    await windowManager.setSkipTaskbar(false);
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _hideWindow() async {
    await windowManager.hide();
    await windowManager.setSkipTaskbar(true);
  }

  Future<void> _openDashboard() async {
    try {
      if (_service.dashboardUrl == null) await _service.startDashboard();
      final url = _service.dashboardUrl;
      if (url == null) throw StateError('Painel local indisponível.');
      await Process.start('explorer.exe', [
        url,
      ], mode: ProcessStartMode.detached);
      await DiagnosticLog.record(
        'Windows',
        'Painel local aberto no navegador.',
      );
    } catch (error, stackTrace) {
      await DiagnosticLog.record(
        'Windows',
        'Não foi possível abrir o painel local.',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) _showMessage(error.toString());
    }
  }

  Future<void> _exitApplication() async {
    _allowClose = true;
    _trayClickTimer?.cancel();
    await _service.stop();
    await _service.stopDashboard();
    await trayManager.destroy();
    await windowManager.setPreventClose(false);
    exit(0);
  }

  @override
  void onWindowClose() {
    if (!_allowClose) unawaited(_hideWindow());
  }

  @override
  void onTrayIconMouseDown() {
    final now = DateTime.now();
    final previous = _lastTrayClick;
    if (previous != null &&
        now.difference(previous) < const Duration(milliseconds: 500)) {
      _trayClickTimer?.cancel();
      _trayClickTimer = null;
      _lastTrayClick = null;
      unawaited(_openDashboard());
      return;
    }
    _lastTrayClick = now;
    _trayClickTimer?.cancel();
    _trayClickTimer = Timer(const Duration(milliseconds: 350), () {
      _lastTrayClick = null;
      unawaited(_openDashboard());
    });
  }

  @override
  void onTrayIconRightMouseDown() {
    unawaited(trayManager.popUpContextMenu());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'open_dashboard':
        unawaited(_openDashboard());
        break;
      case 'show_window':
        unawaited(_showWindow());
        break;
      case 'exit':
        unawaited(_exitApplication());
        break;
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _start() async {
    setState(() => _working = true);
    try {
      await _service.start();
    } catch (error) {
      if (mounted) _showMessage(_service.lastError ?? error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _stop() async {
    setState(() => _working = true);
    await _service.stop();
    if (mounted) setState(() => _working = false);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final padding = width < 700 ? 20.0 : 38.0;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1140),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(padding, 26, padding, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _HostHeader(),
                  const SizedBox(height: 38),
                  Text(
                    'Servidor Windows',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Servidor em segundo plano na bandeja do Windows. Clique duas vezes no ícone para abrir o painel.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF9BAEAE),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _ServerStatusCard(
                    isRunning: _service.isRunning,
                    isWorking: _working,
                    error: _service.lastError,
                    onStart: _start,
                    onStop: _stop,
                    onMinimize: () async {
                      await _hideWindow();
                    },
                  ),
                  if (_service.isRunning) ...[
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 760) {
                          return Column(
                            children: [
                              _PairingCard(
                                payload: _service.pairingQrPayload,
                                expiresAt: _service.pairingExpiresAt,
                                addresses: _service.localAddresses,
                                onNewCode: _service.createPairingCode,
                              ),
                              const SizedBox(height: 16),
                              _ClientsCard(
                                clients: _service.clients,
                                pendingRequests:
                                    _service.pendingPairingRequests,
                                onRevoke: _service.revokeClient,
                                onDecidePairing: _service.decidePairingRequest,
                              ),
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 6,
                              child: _PairingCard(
                                payload: _service.pairingQrPayload,
                                expiresAt: _service.pairingExpiresAt,
                                addresses: _service.localAddresses,
                                onNewCode: _service.createPairingCode,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 4,
                              child: _ClientsCard(
                                clients: _service.clients,
                                pendingRequests:
                                    _service.pendingPairingRequests,
                                onRevoke: _service.revokeClient,
                                onDecidePairing: _service.decidePairingRequest,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 24),
                  const _HostFeatureStrip(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HostHeader extends StatelessWidget {
  const _HostHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF1D3A36),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.cast_connected_rounded,
            color: Color(0xFF77E4D3),
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Open Remote',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        const _HostChip(label: 'WINDOWS'),
        const SizedBox(width: 8),
        const _HostChip(label: 'GPL‑3.0'),
      ],
    );
  }
}

class _ServerStatusCard extends StatelessWidget {
  const _ServerStatusCard({
    required this.isRunning,
    required this.isWorking,
    required this.error,
    required this.onStart,
    required this.onStop,
    required this.onMinimize,
  });

  final bool isRunning;
  final bool isWorking;
  final String? error;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final Future<void> Function() onMinimize;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isRunning
                        ? const Color(0xFF173B33)
                        : const Color(0xFF2A3031),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isRunning ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                    color: isRunning
                        ? const Color(0xFF77E4D3)
                        : const Color(0xFF9BAEAE),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRunning ? 'Servidor ativo' : 'Servidor parado',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isRunning
                            ? 'Aceitando conexões pela rede local.'
                            : 'O PC só aceitará comandos enquanto o servidor estiver ativo.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF9BAEAE),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (isRunning)
                  OutlinedButton.icon(
                    onPressed: isWorking ? null : onStop,
                    icon: const Icon(Icons.stop_rounded),
                    label: const Text('Parar'),
                  )
                else
                  FilledButton.icon(
                    onPressed: isWorking ? null : onStart,
                    icon: isWorking
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                    label: const Text('Iniciar servidor'),
                  ),
              ],
            ),
            if (isRunning) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: isWorking ? null : onMinimize,
                  icon: const Icon(Icons.minimize_rounded),
                  label: const Text('Ocultar na bandeja'),
                ),
              ),
            ],
            if (error != null && !isRunning) ...[
              const SizedBox(height: 14),
              Text(error!, style: const TextStyle(color: Color(0xFFFFA79B))),
            ],
          ],
        ),
      ),
    );
  }
}

class _PairingCard extends StatelessWidget {
  const _PairingCard({
    required this.payload,
    required this.expiresAt,
    required this.addresses,
    required this.onNewCode,
  });

  final String? payload;
  final DateTime? expiresAt;
  final List<String> addresses;
  final Future<void> Function() onNewCode;

  @override
  Widget build(BuildContext context) {
    final payload = this.payload;
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.qr_code_2_rounded),
        title: const Text('Conectar com QR'),
        subtitle: const Text('Leia o código no Android para parear o celular.'),
        childrenPadding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'O QR contém os endereços locais e uma autorização temporária. Ele expira em cinco minutos.',
            style: TextStyle(color: Color(0xFF9BAEAE), height: 1.45),
          ),
          const SizedBox(height: 18),
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: payload == null
                  ? const SizedBox.square(
                      dimension: 196,
                      child: Center(child: Text('QR expirado')),
                    )
                  : QrImageView(
                      data: payload,
                      version: QrVersions.auto,
                      size: 196,
                      backgroundColor: Colors.white,
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            addresses.join('  •  '),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF9BAEAE),
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
          if (expiresAt != null) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Válido até ${TimeOfDay.fromDateTime(expiresAt!).format(context)}',
                style: const TextStyle(color: Color(0xFF9BAEAE), fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 17),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: onNewCode,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Novo QR'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClientsCard extends StatelessWidget {
  const _ClientsCard({
    required this.clients,
    required this.pendingRequests,
    required this.onRevoke,
    required this.onDecidePairing,
  });

  final List<PairedClient> clients;
  final List<PendingPairingRequest> pendingRequests;
  final Future<void> Function(String clientId) onRevoke;
  final Future<void> Function(String requestId, {required bool approve})
  onDecidePairing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pendingRequests.isNotEmpty) ...[
              Text(
                'Pedidos de conexão',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'Confirme no Windows os celulares que podem controlar este PC.',
                style: TextStyle(color: Color(0xFF9BAEAE), height: 1.45),
              ),
              const SizedBox(height: 10),
              ...pendingRequests.map(
                (request) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF1D3A36),
                    child: Icon(
                      Icons.phonelink_ring_rounded,
                      color: Color(0xFF77E4D3),
                    ),
                  ),
                  title: Text(request.clientName),
                  subtitle: Text(request.address),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'Recusar',
                        onPressed: () =>
                            onDecidePairing(request.id, approve: false),
                        icon: const Icon(Icons.close_rounded),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Aprovar',
                        onPressed: () =>
                            onDecidePairing(request.id, approve: true),
                        icon: const Icon(Icons.check_rounded),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 28),
            ],
            Text(
              'Celulares pareados',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Você pode remover o acesso de qualquer dispositivo.',
              style: TextStyle(color: Color(0xFF9BAEAE), height: 1.45),
            ),
            const SizedBox(height: 16),
            if (clients.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 22),
                child: Center(
                  child: Text(
                    'Nenhum celular pareado ainda.',
                    style: TextStyle(color: Color(0xFF9BAEAE)),
                  ),
                ),
              )
            else
              ...clients.map(
                (client) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF1D3A36),
                    child: Icon(
                      Icons.phone_android_rounded,
                      color: Color(0xFF77E4D3),
                    ),
                  ),
                  title: Text(client.name),
                  subtitle: Text(client.connected ? 'Conectado' : 'Pareado'),
                  trailing: IconButton(
                    tooltip: 'Revogar acesso',
                    onPressed: () => onRevoke(client.id),
                    icon: const Icon(Icons.person_remove_alt_1_rounded),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HostFeatureStrip extends StatelessWidget {
  const _HostFeatureStrip();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _HostChip(label: 'MOUSE'),
        _HostChip(label: 'TECLADO'),
        _HostChip(label: 'VOLUME'),
        _HostChip(label: 'MÍDIA'),
        _HostChip(label: 'SOMENTE REDE LOCAL'),
        _HostChip(label: 'SEM BLUETOOTH'),
      ],
    );
  }
}

class _HostChip extends StatelessWidget {
  const _HostChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF202A2C),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: const Color(0xFF344244)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF9BAEAE),
            fontSize: 10,
            letterSpacing: 0.7,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
