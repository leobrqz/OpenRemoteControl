import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'android_update_models.dart';
import 'android_update_platform.dart';
import 'android_update_repository.dart';

/// Coordinates release checks and explicit user actions for the native updater.
class AndroidUpdateController extends ChangeNotifier {
  AndroidUpdateController({
    AndroidUpdateRepository? repository,
    AndroidUpdatePlatform? platform,
  }) : _repository = repository ?? AndroidUpdateRepository(),
       _platform = platform ?? MethodChannelAndroidUpdatePlatform();

  final AndroidUpdateRepository _repository;
  final AndroidUpdatePlatform _platform;

  AndroidUpdateDeviceInfo? deviceInfo;
  AndroidUpdateCandidate? candidate;
  AndroidUpdateState state = AndroidUpdateState.idle;
  String? errorCode;
  double progress = 0;

  bool _eventsStarted = false;
  bool _deferred = false;
  bool _disposed = false;
  StreamSubscription<AndroidUpdateSnapshot>? _eventsSubscription;
  Future<void>? _initializeFuture;
  Future<void>? _checkFuture;
  Future<AndroidUpdateDeviceInfo>? _deviceInfoFuture;
  bool _downloadStarting = false;
  bool _installStarting = false;
  bool _cancelStarting = false;
  bool _transferSettled = false;

  String? get currentVersion => deviceInfo?.versionName;
  bool get busy =>
      _downloadStarting ||
      _installStarting ||
      _cancelStarting ||
      _checkFuture != null ||
      state == AndroidUpdateState.checking ||
      state == AndroidUpdateState.downloading ||
      state == AndroidUpdateState.validating ||
      state == AndroidUpdateState.installing;
  bool get available =>
      state == AndroidUpdateState.available && candidate != null;
  bool get showReminder => available && !_deferred;

  /// Loads Android state once, then begins a non-blocking check for this process.
  Future<void> initialize() => _initializeFuture ??= _initialize();

  Future<void> start() => initialize();

  Future<void> _initialize() async {
    if (_disposed) return;
    try {
      await _loadDeviceInfo();
      if (_disposed) return;
      await refreshNativeState();
      if (!_deferred && !_disposed && !_nativeOperationActive) {
        unawaited(check());
      }
      _notify();
    } catch (error) {
      _setError(_errorCodeFor(error));
    }
  }

  /// Checks GitHub metadata only. APK bytes are fetched after [approveDownload].
  Future<void> check({bool manual = false}) {
    if (_disposed) return Future<void>.value();
    if (manual) _deferred = false;
    if (_checkFuture != null) return _checkFuture!;
    if (_deferred && !manual) return Future<void>.value();
    if (_nativeOperationActive) return Future<void>.value();
    final device = deviceInfo;
    if (device == null) {
      final future = _checkAfterDeviceInfo();
      _checkFuture = future;
      return future;
    }
    final future = _performCheck(device);
    _checkFuture = future;
    return future;
  }

  Future<AndroidUpdateDeviceInfo> _loadDeviceInfo() {
    if (deviceInfo case final info?) return Future.value(info);
    return _deviceInfoFuture ??= (() async {
      final info = await _platform.getDeviceInfo();
      if (!_disposed) {
        deviceInfo = info;
        _subscribeEvents();
        _notify();
      }
      return info;
    })().whenComplete(() => _deviceInfoFuture = null);
  }

  void _subscribeEvents() {
    if (_eventsStarted || _disposed) return;
    try {
      _eventsSubscription = _platform.events.listen(
        _applySnapshot,
        onError: (Object error, StackTrace stack) {
          _setError(_errorCodeFor(error));
        },
      );
      _eventsStarted = true;
    } catch (error) {
      // Test and non-Android hosts can provide method-channel metadata without
      // an event channel. State refresh remains available through getState.
      _setError(_errorCodeFor(error));
    }
  }

  Future<void> _checkAfterDeviceInfo() async {
    try {
      final device = await _loadDeviceInfo();
      if (!_disposed && !_nativeOperationActive) await _performCheck(device);
    } catch (error) {
      if (!_disposed) {
        state = AndroidUpdateState.failed;
        errorCode = _errorCodeFor(error);
      }
    } finally {
      _checkFuture = null;
      _notify();
    }
  }

  Future<void> _performCheck(AndroidUpdateDeviceInfo device) async {
    state = AndroidUpdateState.checking;
    errorCode = null;
    _notify();
    try {
      final result = await _repository.check(device);
      if (_disposed) return;
      if (state == AndroidUpdateState.checking ||
          state == AndroidUpdateState.deferred) {
        candidate = result.candidate;
        state = _deferred
            ? AndroidUpdateState.deferred
            : result.upToDate
            ? AndroidUpdateState.upToDate
            : AndroidUpdateState.available;
        progress = 0;
        errorCode = null;
      }
    } catch (error) {
      if (_disposed) return;
      if (state == AndroidUpdateState.checking ||
          state == AndroidUpdateState.deferred) {
        state = _deferred
            ? AndroidUpdateState.deferred
            : AndroidUpdateState.failed;
        errorCode = _errorCodeFor(error);
      }
    } finally {
      _checkFuture = null;
      _notify();
    }
  }

  /// Starts a native download only after the user approves the visible candidate.
  Future<void> approveDownload({
    required Map<String, String> notification,
  }) async {
    final approved = candidate;
    if (_disposed ||
        !available ||
        approved == null ||
        busy ||
        _downloadStarting) {
      return;
    }
    _downloadStarting = true;
    _transferSettled = false;
    _deferred = false;
    progress = 0;
    errorCode = null;
    state = AndroidUpdateState.downloading;
    _notify();
    try {
      await _platform.download(
        approved,
        notification: immutableNotification(notification),
      );
    } catch (error) {
      if (!_disposed) {
        state = AndroidUpdateState.failed;
        errorCode = _errorCodeFor(error);
      }
    } finally {
      _downloadStarting = false;
      _notify();
    }
  }

  /// Defers the reminder for this controller/process lifetime.
  void defer() {
    if (_disposed) return;
    _deferred = true;
    if (!_nativeOperationActive) state = AndroidUpdateState.deferred;
    errorCode = null;
    _notify();
  }

  Future<void> cancel() async {
    if (_disposed ||
        _cancelStarting ||
        (!_downloadStarting &&
            state != AndroidUpdateState.downloading &&
            state != AndroidUpdateState.validating &&
            state != AndroidUpdateState.ready &&
            state != AndroidUpdateState.permissionRequired &&
            state != AndroidUpdateState.installationCancelled)) {
      return;
    }
    _cancelStarting = true;
    _notify();
    try {
      await _platform.cancel();
      if (!_disposed) {
        candidate = null;
        progress = 0;
        errorCode = null;
        state = AndroidUpdateState.cancelled;
        _transferSettled = true;
      }
    } catch (error) {
      if (!_disposed) _setError(_errorCodeFor(error));
    } finally {
      _cancelStarting = false;
      _notify();
    }
  }

  Future<void> install() async {
    if (_disposed || _installStarting) return;
    _installStarting = true;
    _transferSettled = false;
    errorCode = null;
    _notify();
    try {
      await _platform.install();
      if (!_disposed && state != AndroidUpdateState.permissionRequired) {
        state = AndroidUpdateState.installing;
      }
    } catch (error) {
      if (!_disposed) {
        state = AndroidUpdateState.failed;
        errorCode = _errorCodeFor(error);
      }
    } finally {
      _installStarting = false;
      _notify();
    }
  }

  Future<void> openInstallPermission() async {
    if (_disposed) return;
    try {
      await _platform.openInstallPermission();
      if (!_disposed) await refreshNativeState();
    } catch (error) {
      if (!_disposed) _setError(_errorCodeFor(error));
    }
  }

  Future<void> refreshNativeState() async {
    if (_disposed) return;
    try {
      _applySnapshot(await _platform.getState());
    } catch (error) {
      if (!_disposed) _setError(_errorCodeFor(error));
    }
  }

  void _applySnapshot(AndroidUpdateSnapshot snapshot) {
    if (_disposed) return;
    final incoming = snapshot.state;
    if (incoming == AndroidUpdateState.idle &&
        state != AndroidUpdateState.idle) {
      return;
    }
    final staleTransferEvent =
        _transferSettled &&
        (incoming == AndroidUpdateState.downloading ||
            incoming == AndroidUpdateState.validating ||
            incoming == AndroidUpdateState.ready ||
            incoming == AndroidUpdateState.installing ||
            incoming == AndroidUpdateState.permissionRequired) &&
        !_downloadStarting &&
        !_installStarting;
    if (staleTransferEvent ||
        ((state == AndroidUpdateState.ready ||
                state == AndroidUpdateState.installing ||
                state == AndroidUpdateState.permissionRequired ||
                state == AndroidUpdateState.installationCancelled) &&
            (incoming == AndroidUpdateState.downloading ||
                incoming == AndroidUpdateState.validating) &&
            !_downloadStarting)) {
      return;
    }
    // Some native events omit candidate. Preserve it across progress and terminal
    // transitions so the UI can retry installation or inspect release notes.
    candidate = snapshot.candidate ?? candidate;
    state = snapshot.state;
    errorCode = snapshot.errorCode;
    final ratio = snapshot.progress;
    if (ratio != null) progress = ratio;
    if (state == AndroidUpdateState.idle ||
        state == AndroidUpdateState.cancelled ||
        state == AndroidUpdateState.failed) {
      progress = 0;
    }
    if (state == AndroidUpdateState.cancelled) candidate = null;
    _transferSettled =
        state == AndroidUpdateState.ready ||
        state == AndroidUpdateState.cancelled ||
        state == AndroidUpdateState.failed ||
        state == AndroidUpdateState.installationCancelled;
    _notify();
  }

  bool get _nativeOperationActive =>
      state == AndroidUpdateState.downloading ||
      state == AndroidUpdateState.validating ||
      state == AndroidUpdateState.ready ||
      state == AndroidUpdateState.installing ||
      state == AndroidUpdateState.permissionRequired ||
      state == AndroidUpdateState.installationCancelled;

  void _setError(String code) {
    if (_disposed) return;
    errorCode = code;
    _notify();
  }

  String _errorCodeFor(Object error) {
    if (error is AndroidUpdateException) return error.code;
    if (error is PlatformException) {
      const valid = {
        'network',
        'unavailable',
        'storage',
        'integrity',
        'identity',
        'signature',
        'incompatible',
        'invalidPackage',
        'permission',
        'installer',
        'interrupted',
        'busy',
      };
      return valid.contains(error.code) ? error.code : 'unavailable';
    }
    return 'unavailable';
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_eventsSubscription?.cancel());
    super.dispose();
  }
}
