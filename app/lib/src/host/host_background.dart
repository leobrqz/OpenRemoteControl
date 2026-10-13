import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:tray_manager/tray_manager.dart';

import '../core/diagnostic_log.dart';
import 'host_service.dart';

class HostBackground extends StatefulWidget {
  const HostBackground({super.key});

  @override
  State<HostBackground> createState() => _HostBackgroundState();
}

class _HostBackgroundState extends State<HostBackground> with TrayListener {
  final RemoteHostService _service = RemoteHostService();
  bool _trayReady = false;
  Timer? _trayClickTimer;
  DateTime? _lastTrayClick;

  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initializeBackgroundServer());
    });
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    _trayClickTimer?.cancel();
    _service.dispose();
    super.dispose();
  }

  Future<void> _initializeBackgroundServer() async {
    try {
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
      if (_service.isRunning && !_trayReady) unawaited(_openDashboard());
    } catch (error, stackTrace) {
      await DiagnosticLog.record(
        'Windows',
        'Falha ao preparar o servidor em segundo plano.',
        error: error,
        stackTrace: stackTrace,
      );
      if (_service.dashboardUrl != null) unawaited(_openDashboard());
    }
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
    }
  }

  Future<void> _exitApplication() async {
    _trayClickTimer?.cancel();
    await _service.stop();
    await _service.stopDashboard();
    await trayManager.destroy();
    exit(0);
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
      case 'exit':
        unawaited(_exitApplication());
        break;
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
