import 'dart:async';

/// Sends the initial state and subsequent changes for one authorized session.
class StatePublisher<T> {
  StatePublisher({
    required this.read,
    required this.send,
    required this.onReadError,
    required this.onSendError,
    this.equals,
    this.interval = const Duration(milliseconds: 500),
  });

  final Future<T?> Function() read;
  final Future<void> Function(T?) send;
  final void Function(Object, StackTrace) onReadError;
  final void Function(Object, StackTrace) onSendError;
  final bool Function(T?, T?)? equals;
  final Duration interval;

  Timer? _timer;
  bool _stopped = false;
  bool _updating = false;
  bool _hasSent = false;
  bool _readFailed = false;
  T? _lastSent;

  void start() {
    if (_timer != null || _stopped) return;
    _timer = Timer.periodic(interval, (_) => unawaited(_update()));
    unawaited(_update());
  }

  void stop() {
    _stopped = true;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _update() async {
    if (_stopped || _updating) return;
    _updating = true;
    try {
      T? state;
      try {
        state = await read();
        _readFailed = false;
      } catch (error, stackTrace) {
        if (!_readFailed && !_stopped) onReadError(error, stackTrace);
        _readFailed = true;
      }
      if (_stopped ||
          (_hasSent &&
              (equals?.call(state, _lastSent) ?? state == _lastSent))) {
        return;
      }
      try {
        await send(state);
        _lastSent = state;
        _hasSent = true;
      } catch (error, stackTrace) {
        if (!_stopped) onSendError(error, stackTrace);
      }
    } finally {
      _updating = false;
    }
  }
}
