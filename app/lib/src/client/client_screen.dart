import 'dart:async';

import 'package:flutter/material.dart';

import 'about_page.dart';
import 'about_service.dart';
import 'client_drawer.dart';
import 'client_service.dart';
import 'computers_page.dart';
import 'controls/keyboard_control.dart';
import 'controls/media_control.dart';
import 'controls/mouse_control.dart';
import 'controls/remote_actions.dart';
import 'manual_connection_dialog.dart';
import 'pairing_scanner_screen.dart';
import 'preferences/client_preferences.dart';
import 'preferences/settings_page.dart';

import 'client_view_model.dart';

class ClientScreen extends StatefulWidget {
  const ClientScreen({
    super.key,
    required this.preferences,
    this.service,
    this.aboutService,
  });
  final PreferencesController preferences;
  final RemoteClientService? service;
  final AboutService? aboutService;
  @override
  State<ClientScreen> createState() => _ClientScreenState();
}

class _ClientScreenState extends State<ClientScreen>
    with WidgetsBindingObserver {
  late final _model = ClientViewModel(
    preferences: widget.preferences,
    service: widget.service,
  );
  ClientNotice? _lastNotice;
  RemoteClientService get _service => _model.service;
  RemoteActions get _actions => _model.actions;
  List<SavedHost> get _savedHosts => _model.savedHosts;
  bool get _loadingHosts => _model.loadingHosts;
  bool get _foreground => _model.foreground;
  bool get _retrying => _model.retrying;
  ClientDestination get _destination => _model.destination;
  ControlPage get _control => _model.control;
  ClientPreferences get _preferences => widget.preferences.value;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _model.addListener(_showNotice);
  }

  void _showNotice() {
    final notice = _model.notice;
    if (notice == null || identical(notice, _lastNotice)) return;
    _lastNotice = notice;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(notice.message)));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _model.onLifecycleStateChanged(state);
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _model.removeListener(_showNotice);
    _model.dispose();
    super.dispose();
  }

  void _select(ClientDestination destination, ControlPage? control) {
    FocusManager.instance.primaryFocus?.unfocus();
    _model.select(destination, control);
  }

  Future<void> _scan() async {
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const PairingScannerScreen()),
    );
    if (raw != null && mounted) await _model.connectQr(raw);
  }

  Future<void> _manual() async {
    ManualEndpoint? initial;
    try {
      final saved = await _service.loadManualEndpoint();
      if (saved != null) {
        initial = (
          address: saved['address'] as String,
          port: saved['port'] as int,
        );
      }
    } catch (_) {
      /* A missing saved endpoint does not prevent manual entry. */
    }
    if (!mounted) return;
    final endpoint = await showDialog<ManualEndpoint>(
      context: context,
      builder: (_) => ManualConnectionDialog(initial: initial),
    );
    if (endpoint != null) {
      await _model.connectManual(endpoint.address, endpoint.port);
    }
  }

  Future<void> _forget(SavedHost host) async {
    final forget = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Esquecer ${host.name}?'),
        content: const Text(
          'Será necessário autorizar este celular novamente para conectar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Esquecer'),
          ),
        ],
      ),
    );
    if (forget != true) return;
    await _model.forgetHost(host);
  }

  Widget _controls() {
    final active =
        _destination == ClientDestination.controls &&
        _foreground &&
        _service.isConnected;
    return Column(
      children: [
        if (!_service.isConnected)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_service.isConnecting) const LinearProgressIndicator(),
                Text(
                  _service.isConnecting
                      ? 'Reconectando…'
                      : _preferences.showConnectionErrors
                      ? _service.lastError ?? 'Desconectado'
                      : 'Desconectado',
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: _service.isConnecting || _retrying
                          ? null
                          : _model.reconnect,
                      child: const Text('Reconectar'),
                    ),
                    TextButton(
                      onPressed: _service.disconnect,
                      child: const Text('Desconectar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        Expanded(
          child: IndexedStack(
            index: _control.index,
            children: [
              MouseControl(
                actions: _actions,
                preferences: _preferences,
                active: active && _control == ControlPage.mouse,
              ),
              MediaControl(
                actions: _actions,
                active: active && _control == ControlPage.media,
              ),
              KeyboardControl(
                actions: _actions,
                active: active && _control == ControlPage.keyboard,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShell(BuildContext context) {
    final controls = ControlPage.values
        .where(_preferences.visibleControls.contains)
        .toList();
    return PopScope(
      canPop: _destination == ClientDestination.computers,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) _select(ClientDestination.computers, null);
      },
      child: Scaffold(
        drawerEnableOpenDragGesture: _preferences.swipeToOpenMenu,
        drawer: ClientDrawer(
          destination: _destination,
          control: _control,
          preferences: _preferences,
          hasSession: _service.hasSession,
          select: (destination, control) {
            Navigator.pop(context);
            _select(destination, control);
          },
        ),
        appBar: AppBar(
          title: Text(
            switch (_destination) {
              ClientDestination.computers => 'Computadores',
              ClientDestination.settings => 'Configurações',
              ClientDestination.about => 'Sobre',
              ClientDestination.controls =>
                '${_control.label} · ${_service.currentHost?.name ?? 'PC'}',
            },
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (_destination == ClientDestination.computers) ...[
              IconButton(
                tooltip: 'Procurar computadores',
                onPressed: _service.isDiscovering || _service.isConnecting
                    ? null
                    : () => _model.discover(showError: true),
                icon: const Icon(Icons.refresh),
              ),
              PopupMenuButton<String>(
                tooltip: 'Adicionar computador',
                enabled: !_service.isConnecting,
                icon: const Icon(Icons.add),
                onSelected: (choice) =>
                    choice == 'qr' ? unawaited(_scan()) : unawaited(_manual()),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'qr', child: Text('Escanear QR')),
                  PopupMenuItem(value: 'ip', child: Text('Conectar por IP')),
                ],
              ),
            ],
            if (_destination == ClientDestination.controls)
              IconButton(
                tooltip: 'Desconectar',
                onPressed: _service.disconnect,
                icon: const Icon(Icons.link_off_rounded),
              ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: IndexedStack(
            index: _destination.index,
            children: [
              ComputersPage(
                service: _service,
                savedHosts: _savedHosts,
                loading: _loadingHosts,
                showErrors: _preferences.showConnectionErrors,
                onConnectSaved: (host) => unawaited(_model.connectSaved(host)),
                onConnectDiscovered: (host) =>
                    unawaited(_model.connectDiscovered(host)),
                onOpenControls: () => _select(
                  ClientDestination.controls,
                  _preferences.defaultControl,
                ),
                onForget: (host) => unawaited(_forget(host)),
                onAdd: _manual,
              ),
              _service.hasSession ? _controls() : const SizedBox.shrink(),
              SettingsPage(
                preferences: widget.preferences,
                onComputers: () => _select(ClientDestination.computers, null),
                onTestMouse: _model.testMouse,
                onDiagnostics: () => unawaited(_model.copyDiagnostics()),
              ),
              AboutPage(
                enabled: _destination == ClientDestination.about,
                service: widget.aboutService,
              ),
            ],
          ),
        ),
        bottomNavigationBar:
            _destination == ClientDestination.controls &&
                _preferences.controlLayout == ControlLayout.tabs &&
                controls.length > 1
            ? NavigationBar(
                selectedIndex: controls.indexOf(_control),
                onDestinationSelected: (index) =>
                    _select(ClientDestination.controls, controls[index]),
                destinations: [
                  for (final page in controls)
                    NavigationDestination(
                      icon: Icon(page.icon),
                      label: page.label,
                    ),
                ],
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _model,
    builder: (context, _) => _buildShell(context),
  );
}
