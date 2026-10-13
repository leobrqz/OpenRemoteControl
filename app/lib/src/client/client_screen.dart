import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/diagnostic_log.dart';
import '../core/wire.dart';
import 'client_drawer.dart';
import 'client_service.dart';
import 'computers_page.dart';
import 'controls/keyboard_control.dart';
import 'controls/media_control.dart';
import 'controls/mouse_control.dart';
import 'controls/remote_actions.dart';
import 'manual_connection_dialog.dart';
import 'pairing_scanner_screen.dart';
import 'preferences/client_platform.dart';
import 'preferences/client_preferences.dart';
import 'preferences/settings_page.dart';

class ClientScreen extends StatefulWidget {
  const ClientScreen({super.key, required this.preferences, this.service});
  final PreferencesController preferences;
  final RemoteClientService? service;
  @override
  State<ClientScreen> createState() => _ClientScreenState();
}

class _ClientScreenState extends State<ClientScreen>
    with WidgetsBindingObserver {
  late final _service = widget.service ?? RemoteClientService();
  late final _actions = RemoteActions(
    send: _service.send,
    preferences: () => widget.preferences.value,
    connected: () => _service.isConnected,
    onError: (error) => _message(error.toString(), error: true),
  );
  List<SavedHost> _savedHosts = const [];
  bool _loadingHosts = true,
      _foreground = true,
      _connecting = false,
      _retrying = false;
  ClientDestination _destination = ClientDestination.computers;
  late ControlPage _control = widget.preferences.value.defaultControl;
  Timer? _discoveryTimer, _reconnectTimer;
  Future<void>? _discovery;
  int _retryAttempt = 0;
  Object? _displayState, _backgroundState;
  Future<void> _platformQueue = Future<void>.value();
  ClientPreferences get _preferences => widget.preferences.value;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service.addListener(_refresh);
    widget.preferences.addListener(_preferencesChanged);
    unawaited(_loadHosts());
    if (_preferences.automaticDiscovery) unawaited(_discover());
    _discoveryTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_foreground &&
          _preferences.automaticDiscovery &&
          !_service.isConnected) {
        unawaited(_discover());
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncPlatform());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _service.removeListener(_refresh);
    widget.preferences.removeListener(_preferencesChanged);
    _discoveryTimer?.cancel();
    _reconnectTimer?.cancel();
    _actions.dispose();
    unawaited(
      ClientPlatform.setBackgroundConnection(
        false,
        null,
      ).catchError((Object _) {}),
    );
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) _actions.releaseAll();
    if (_foreground) {
      if (_preferences.automaticDiscovery && !_service.isConnected) {
        unawaited(_discover());
      }
      _scheduleReconnect();
    } else if (!_preferences.keepConnectionInBackground) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
    }
    _syncPlatform();
    if (mounted) {
      setState(() {});
    }
  }

  void _refresh() {
    if (!mounted) return;
    if (!_service.isConnected) _actions.releaseAll();
    if (!_service.hasSession && _destination == ClientDestination.controls) {
      _destination = ClientDestination.computers;
    }
    if (_service.isConnected || !_service.hasSession) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _retryAttempt = 0;
    } else {
      _scheduleReconnect();
    }
    _syncPlatform();
    setState(() {});
  }

  void _preferencesChanged() {
    if (!_preferences.visibleControls.contains(_control)) {
      _control = _preferences.defaultControl;
    }
    if (!_preferences.autoReconnect) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
    } else {
      _scheduleReconnect();
    }
    _syncPlatform();
    if (mounted) setState(() {});
  }

  void _syncPlatform() {
    if (!mounted) return;
    final p = _preferences;
    final controlling =
        _foreground &&
        _destination == ClientDestination.controls &&
        _service.isConnected;
    final display = (
      p.orientation,
      p.fullscreen,
      p.keepScreenAwake && controlling,
    );
    final keepBackground =
        p.keepConnectionInBackground &&
        (_service.isConnected || (p.autoReconnect && _service.hasSession));
    final background = (keepBackground, _service.connectedAddress);
    if (display != _displayState) {
      _displayState = display;
      _platformQueue = _platformQueue
          .then((_) => ClientPlatform.applyDisplay(p, controlling: controlling))
          .catchError((Object error, StackTrace stack) async {
            _displayState = null;
            await DiagnosticLog.record(
              'Android',
              'Falha ao aplicar opções de tela.',
              error: error,
              stackTrace: stack,
            );
          });
    }
    if (background != _backgroundState) {
      _backgroundState = background;
      _platformQueue = _platformQueue
          .then(
            (_) => ClientPlatform.setBackgroundConnection(
              keepBackground,
              background.$2,
            ),
          )
          .catchError((Object error, StackTrace stack) async {
            _backgroundState = null;
            await DiagnosticLog.record(
              'Android',
              'Falha ao manter conexão em segundo plano.',
              error: error,
              stackTrace: stack,
            );
            if (mounted && keepBackground) {
              await widget.preferences.update(
                _preferences.copyWith(keepConnectionInBackground: false),
              );
              _message(
                'Não foi possível manter a conexão em segundo plano.',
                error: true,
              );
            }
          });
    }
  }

  Future<void> _loadHosts() async {
    try {
      final hosts = await _service.loadSavedHosts();
      if (mounted) {
        setState(() {
          _savedHosts = hosts;
          _loadingHosts = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _loadingHosts = false);
        _message(
          'Não foi possível ler os computadores salvos: $error',
          error: true,
        );
      }
    }
  }

  Future<void> _discover({bool showError = false}) {
    if (_discovery != null) return _discovery!;
    if (_service.isConnecting || _connecting || _service.isConnected) {
      return Future<void>.value();
    }
    final operation = _performDiscovery(showError);
    _discovery = operation;
    return operation.whenComplete(() => _discovery = null);
  }

  Future<void> _performDiscovery(bool showError) async {
    try {
      await _service.discoverHosts();
      if (_preferences.updateServerAddress) {
        await _service.updateDiscoveredAddresses();
        await _loadHosts();
      }
    } catch (error) {
      if (showError) {
        _message('Falha ao procurar computadores: $error', error: true);
      }
    }
  }

  void _scheduleReconnect() {
    if (!mounted ||
        !_preferences.autoReconnect ||
        !_service.hasSession ||
        _service.isConnected ||
        _service.isConnecting ||
        _connecting ||
        _retrying ||
        _reconnectTimer != null ||
        (!_foreground && !_preferences.keepConnectionInBackground)) {
      return;
    }
    final delay = [1, 2, 4, 8, 15, 30][_retryAttempt.clamp(0, 5)];
    _reconnectTimer = Timer(Duration(seconds: delay), () {
      _reconnectTimer = null;
      unawaited(_reconnect(automatic: true));
    });
  }

  Future<void> _reconnect({bool automatic = false}) async {
    if (_retrying ||
        _service.isConnected ||
        _service.isConnecting ||
        !_service.hasSession) {
      return;
    }
    _retrying = true;
    try {
      if (_preferences.updateServerAddress) await _discover();
      if (!_service.hasSession ||
          !mounted ||
          (automatic && !_preferences.autoReconnect) ||
          (!_foreground && !_preferences.keepConnectionInBackground)) {
        return;
      }
      await _service.reconnect();
    } catch (_) {
      _retryAttempt++;
    } finally {
      _retrying = false;
      _scheduleReconnect();
    }
  }

  Future<void> _connect(Future<void> Function() operation) async {
    if (_service.isConnecting || _connecting || _retrying) return;
    _connecting = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    try {
      await _discovery;
      await operation();
      if (!mounted || !_service.isConnected) return;
      _select(ClientDestination.controls, _preferences.defaultControl);
      await _loadHosts();
    } catch (error) {
      _message(_service.lastError ?? error.toString(), error: true);
    } finally {
      _connecting = false;
      _scheduleReconnect();
    }
  }

  Future<void> _scan() async {
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const PairingScannerScreen()),
    );
    if (raw == null || !mounted) return;
    try {
      final pairing = PairingInfo.fromQr(raw);
      await _connect(() => _service.connectFromQr(pairing));
    } catch (error) {
      _message(error.toString(), error: true);
    }
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
      await _connect(
        () => _service.connectManual(
          address: endpoint.address,
          port: endpoint.port,
        ),
      );
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
    try {
      await _service.forgetHost(host.serverId);
      await _loadHosts();
    } catch (error) {
      _message('Não foi possível esquecer o computador: $error', error: true);
    }
  }

  Future<void> _diagnostics() async {
    await Clipboard.setData(ClipboardData(text: await DiagnosticLog.export()));
    _message('Diagnóstico copiado.');
  }

  void _message(String message, {bool error = false}) {
    if (!mounted || (error && !_preferences.showConnectionErrors)) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _select(ClientDestination destination, ControlPage? control) {
    _actions.releaseAll();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _destination = destination;
      if (control != null) _control = control;
    });
    _syncPlatform();
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
                          : _reconnect,
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

  @override
  Widget build(BuildContext context) {
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
                    : () => _discover(showError: true),
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
                onConnectSaved: (host) =>
                    unawaited(_connect(() => _service.connectSaved(host))),
                onConnectDiscovered: (host) =>
                    unawaited(_connect(() => _service.connectDiscovered(host))),
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
                onTestMouse: () {
                  if (_service.hasSession) {
                    if (!_preferences.visibleControls.contains(
                      ControlPage.mouse,
                    )) {
                      unawaited(
                        widget.preferences.update(
                          _preferences.copyWith(
                            visibleControls: {
                              ..._preferences.visibleControls,
                              ControlPage.mouse,
                            },
                          ),
                        ),
                      );
                    }
                    _select(ClientDestination.controls, ControlPage.mouse);
                  } else {
                    _message('Conecte a um computador para testar o mouse.');
                  }
                },
                onDiagnostics: () => unawaited(_diagnostics()),
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
}
