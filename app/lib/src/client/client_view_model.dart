import 'dart:async';
import 'dart:ui' show AppLifecycleState;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:open_remote_core/open_remote_core.dart';

import 'client_destination.dart';
import 'client_message.dart';
import 'client_service.dart';
import 'controls/remote_actions.dart';
import 'preferences/client_platform.dart';
import 'preferences/client_preferences.dart';

class ClientNotice {
  const ClientNotice(this.message);
  final ClientMessage message;
}

class ClientViewModel extends ChangeNotifier {
  ClientViewModel({required this.preferences, RemoteClientService? service})
    : service = service ?? RemoteClientService(),
      _ownsService = service == null {
    _control = preferences.value.defaultControl;
    this.service.addListener(_refresh);
    preferences.addListener(_preferencesChanged);
    unawaited(_loadHosts());
    if (_preferences.automaticDiscovery) unawaited(discover());
    _discoveryTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_foreground &&
          _preferences.automaticDiscovery &&
          !this.service.isConnected) {
        unawaited(discover());
      }
    });
    _syncPlatform();
  }

  final PreferencesController preferences;
  final RemoteClientService service;
  final bool _ownsService;
  bool _disposed = false;
  bool get _alive => !_disposed;
  late final _actions = RemoteActions(
    send: service.send,
    preferences: () => preferences.value,
    connected: () => service.isConnected,
    onError: (error) => _message(ClientMessage.fromError(error), error: true),
  );
  List<SavedHost> _savedHosts = const [];
  bool _loadingHosts = true,
      _foreground = true,
      _connecting = false,
      _retrying = false;
  ClientDestination _destination = ClientDestination.computers;
  late ControlPage _control;
  Timer? _discoveryTimer, _reconnectTimer;
  Future<void>? _discovery;
  int _retryAttempt = 0;
  Object? _displayState, _backgroundState;
  String? _platformLanguage;
  Future<void> _platformQueue = Future<void>.value();
  ClientPreferences get _preferences => preferences.value;
  ClientNotice? _notice;
  ClientNotice? get notice => _notice;
  List<SavedHost> get savedHosts => List.unmodifiable(_savedHosts);
  bool get loadingHosts => _loadingHosts;
  bool get foreground => _foreground;
  bool get retrying => _retrying;
  ClientDestination get destination => _destination;
  ControlPage get control => _control;
  RemoteActions get actions => _actions;

  void _message(ClientMessage message, {bool error = false}) {
    if (!_alive || (error && !_preferences.showConnectionErrors)) return;
    _notice = ClientNotice(message);
    notifyListeners();
  }

  void select(ClientDestination destination, ControlPage? control) {
    _actions.releaseAll();
    _destination = destination;
    if (control != null) _control = control;
    _syncPlatform();
    notifyListeners();
  }

  Future<void> connectSaved(SavedHost host) =>
      _connect(() => service.connectSaved(host));
  Future<void> connectDiscovered(DiscoveredHost host) =>
      _connect(() => service.connectDiscovered(host));
  Future<void> connectManual(String address, int port) =>
      _connect(() => service.connectManual(address: address, port: port));
  Future<void> connectQr(String raw) => _connect(() {
    late final PairingInfo pairing;
    try {
      pairing = PairingInfo.fromQr(raw);
    } on FormatException catch (error) {
      throw ClientMessageException(ClientMessage('invalidQr', detail: error));
    }
    return service.connectFromQr(pairing);
  });
  Future<void> forgetHost(SavedHost host) async {
    try {
      await service.forgetHost(host.serverId);
      await _loadHosts();
    } catch (error) {
      await DiagnosticLog.record(
        'Android',
        'Failed to forget paired computer.',
        error: error,
      );
      _message(const ClientMessage('forgetComputerFailed'), error: true);
    }
  }

  Future<void> copyDiagnostics() async {
    await Clipboard.setData(ClipboardData(text: await DiagnosticLog.export()));
    _message(const ClientMessage('diagnosticsCopied'));
  }

  void testMouse() {
    if (!service.hasSession) {
      _message(const ClientMessage('connectToTestMouse'));
      return;
    }
    if (!_preferences.visibleControls.contains(ControlPage.mouse)) {
      unawaited(
        preferences.update(
          _preferences.copyWith(
            visibleControls: {
              ..._preferences.visibleControls,
              ControlPage.mouse,
            },
          ),
        ),
      );
    }
    select(ClientDestination.controls, ControlPage.mouse);
  }

  void onLifecycleStateChanged(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) _actions.releaseAll();
    if (_foreground) {
      if (_preferences.automaticDiscovery && !service.isConnected) {
        unawaited(discover());
      }
      _scheduleReconnect();
    } else if (!_preferences.keepConnectionInBackground) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
    }
    _syncPlatform();
    if (_alive) {
      notifyListeners();
    }
  }

  void _refresh() {
    if (!_alive) return;
    if (!service.isConnected) _actions.releaseAll();
    if (!service.hasSession && _destination == ClientDestination.controls) {
      _destination = ClientDestination.computers;
    }
    if (service.isConnected || !service.hasSession) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _retryAttempt = 0;
    } else {
      _scheduleReconnect();
    }
    _syncPlatform();
    notifyListeners();
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
    if (_alive) {
      notifyListeners();
    }
  }

  void _syncPlatform() {
    if (!_alive) return;
    final p = _preferences;
    if (_platformLanguage != p.language) {
      _platformLanguage = p.language;
      unawaited(
        ClientPlatform.setLanguage(p.language).catchError((
          Object error,
          StackTrace stack,
        ) async {
          _platformLanguage = null;
          await DiagnosticLog.record(
            'Android',
            'Failed to apply app language preference.',
            error: error,
            stackTrace: stack,
          );
        }),
      );
    }
    final controlling =
        _foreground &&
        _destination == ClientDestination.controls &&
        service.isConnected;
    final display = (
      p.orientation,
      p.fullscreen,
      p.keepScreenAwake && controlling,
    );
    final keepBackground =
        p.keepConnectionInBackground &&
        (service.isConnected || (p.autoReconnect && service.hasSession));
    final background = (keepBackground, service.connectedAddress);
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
            if (_alive && keepBackground) {
              await preferences.update(
                _preferences.copyWith(keepConnectionInBackground: false),
              );
              _message(
                const ClientMessage('backgroundConnectionFailed'),
                error: true,
              );
            }
          });
    }
  }

  Future<void> _loadHosts() async {
    try {
      final hosts = await service.loadSavedHosts();
      if (!_alive) return;
      _savedHosts = hosts;
      _loadingHosts = false;
      notifyListeners();
    } catch (error) {
      if (!_alive) return;
      _loadingHosts = false;
      await DiagnosticLog.record(
        'Android',
        'Failed to load saved computers.',
        error: error,
      );
      _message(const ClientMessage('connectionFailed'), error: true);
    }
  }

  Future<void> discover({bool showError = false}) {
    if (_discovery != null) return _discovery!;
    if (service.isConnecting || _connecting || service.isConnected) {
      return Future<void>.value();
    }
    final operation = _performDiscovery(showError);
    _discovery = operation;
    return operation.whenComplete(() => _discovery = null);
  }

  Future<void> _performDiscovery(bool showError) async {
    try {
      await service.discoverHosts();
      if (_preferences.updateServerAddress) {
        await service.updateDiscoveredAddresses();
        await _loadHosts();
      }
    } catch (error) {
      if (showError) {
        await DiagnosticLog.record(
          'Android',
          'Failed to discover computers.',
          error: error,
        );
        _message(const ClientMessage('discoverComputersFailed'), error: true);
      }
    }
  }

  void _scheduleReconnect() {
    if (!_alive ||
        !_preferences.autoReconnect ||
        !service.hasSession ||
        service.isConnected ||
        service.isConnecting ||
        _connecting ||
        _retrying ||
        _reconnectTimer != null ||
        (!_foreground && !_preferences.keepConnectionInBackground)) {
      return;
    }
    final delay = [1, 2, 4, 8, 15, 30][_retryAttempt.clamp(0, 5)];
    _reconnectTimer = Timer(Duration(seconds: delay), () {
      _reconnectTimer = null;
      unawaited(reconnect(automatic: true));
    });
  }

  Future<void> reconnect({bool automatic = false}) async {
    if (_retrying ||
        service.isConnected ||
        service.isConnecting ||
        !service.hasSession) {
      return;
    }
    _retrying = true;
    try {
      if (_preferences.updateServerAddress) await discover();
      if (!service.hasSession ||
          !_alive ||
          (automatic && !_preferences.autoReconnect) ||
          (!_foreground && !_preferences.keepConnectionInBackground)) {
        return;
      }
      await service.reconnect();
    } catch (_) {
      _retryAttempt++;
    } finally {
      _retrying = false;
      _scheduleReconnect();
    }
  }

  Future<void> _connect(Future<void> Function() operation) async {
    if (service.isConnecting || _connecting || _retrying) return;
    _connecting = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    try {
      await _discovery;
      await operation();
      if (!_alive || !service.isConnected) return;
      select(ClientDestination.controls, _preferences.defaultControl);
      await _loadHosts();
    } catch (error) {
      await DiagnosticLog.record(
        'Android',
        'Connection attempt failed.',
        error: error,
      );
      _message(
        service.lastError ?? ClientMessage.fromError(error),
        error: true,
      );
    } finally {
      _connecting = false;
      _scheduleReconnect();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    service.removeListener(_refresh);
    preferences.removeListener(_preferencesChanged);
    _discoveryTimer?.cancel();
    _reconnectTimer?.cancel();
    _actions.dispose();
    unawaited(
      _platformQueue
          .then((_) => ClientPlatform.setBackgroundConnection(false, null))
          .catchError((Object _) {}),
    );
    if (_ownsService) service.dispose();
    super.dispose();
  }
}
