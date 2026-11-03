import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'wire.dart';

/// A stream of the existing protocol's text frames, independent of transport.
abstract class ControlChannel extends Stream<Object?> {
  bool get isOpen;
  void add(String frame);
  Future<void> close([int? code]);
}

class WebSocketControlChannel extends ControlChannel {
  WebSocketControlChannel(this.socket);
  final WebSocket socket;

  @override
  bool get isOpen => socket.readyState == WebSocket.open;
  @override
  void add(String frame) => socket.add(frame);
  @override
  Future<void> close([int? code]) async => socket.close(code);
  @override
  StreamSubscription<Object?> listen(
    void Function(Object?)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => socket.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
}

/// Frames text messages on an ordered byte stream using a bounded length prefix.
class FramedControlChannel extends ControlChannel {
  FramedControlChannel({
    required this.read,
    required this.write,
    required this.release,
    Duration keepAlive = const Duration(seconds: 20),
  }) {
    _controller = StreamController<Object?>(
      onListen: () => unawaited(_readFrames()),
      onPause: () => _resumed ??= Completer<void>(),
      onResume: _resume,
      sync: true,
    );
    _keepAlive = Timer.periodic(keepAlive, (_) {
      if (_open) {
        try {
          _enqueue(Uint8List(4));
        } catch (_) {
          // The channel has already been closed on overload.
        }
      }
    });
  }

  static const _maxFrameBytes = maxWireFrameCharacters * 4;
  static const _maxQueuedBytes = 1024 * 1024;
  final Future<Uint8List?> Function(int) read;
  final Future<void> Function(List<int>) write;
  final Future<void> Function() release;
  late final StreamController<Object?> _controller;
  late final Timer _keepAlive;
  Future<void> _writes = Future<void>.value();
  Future<void>? _closing;
  Completer<void>? _resumed;
  bool _open = true;
  int _queuedBytes = 0;

  @override
  bool get isOpen => _open;

  @override
  void add(String frame) {
    if (!_open) throw StateError('Control channel is closed.');
    final bytes = utf8.encode(frame);
    if (frame.length > maxWireFrameCharacters ||
        bytes.length > _maxFrameBytes) {
      throw const FormatException('Control frame is too large.');
    }
    final packet = Uint8List(4 + bytes.length);
    ByteData.sublistView(packet).setUint32(0, bytes.length);
    packet.setRange(4, packet.length, bytes);
    _enqueue(packet);
  }

  void _enqueue(Uint8List packet) {
    if (_queuedBytes + packet.length > _maxQueuedBytes) {
      final error = StateError('Control channel is overloaded.');
      if (!_controller.isClosed) _controller.addError(error);
      unawaited(close());
      throw error;
    }
    _queuedBytes += packet.length;
    _writes = _writes
        .then((_) => write(packet))
        .catchError((Object error, StackTrace stack) {
          if (_open && !_controller.isClosed) {
            _controller.addError(error, stack);
          }
          unawaited(close());
        })
        .whenComplete(() => _queuedBytes -= packet.length);
  }

  Future<Uint8List?> _readExactly(int length) async {
    final result = Uint8List(length);
    var offset = 0;
    while (offset < length) {
      final part = await read(length - offset);
      if (part == null) {
        if (offset == 0) return null;
        throw const FormatException('Truncated control frame.');
      }
      if (part.isEmpty || part.length > length - offset) {
        throw const FormatException('Invalid control stream.');
      }
      result.setRange(offset, offset + part.length, part);
      offset += part.length;
    }
    return result;
  }

  Future<void> _readFrames() async {
    try {
      while (_open) {
        while (_open && _controller.isPaused) {
          _resumed ??= Completer<void>();
          await _resumed!.future;
        }
        if (!_open) break;
        final header = await _readExactly(4);
        if (header == null) break;
        final length = ByteData.sublistView(header).getUint32(0);
        if (length == 0) continue; // Keep the connection alive through NATs.
        if (length > _maxFrameBytes) {
          throw const FormatException('Control frame is too large.');
        }
        final bytes = await _readExactly(length);
        if (bytes == null) {
          throw const FormatException('Truncated control frame.');
        }
        final frame = utf8.decode(bytes);
        if (frame.length > maxWireFrameCharacters) {
          throw const FormatException('Control frame is too large.');
        }
        if (!_controller.isClosed) _controller.add(frame);
      }
    } catch (error, stack) {
      if (_open && !_controller.isClosed) _controller.addError(error, stack);
    } finally {
      unawaited(close());
    }
  }

  @override
  Future<void> close([int? code]) => _closing ??= _close();

  Future<void> _close() async {
    _open = false;
    _keepAlive.cancel();
    _resume();
    try {
      await _writes.timeout(const Duration(seconds: 2));
    } catch (_) {}
    try {
      await release();
    } catch (_) {
      // Releasing a disconnected transport must still finish the stream.
    } finally {
      if (!_controller.isClosed) unawaited(_controller.close());
    }
  }

  void _resume() {
    final resumed = _resumed;
    _resumed = null;
    if (resumed != null && !resumed.isCompleted) resumed.complete();
  }

  @override
  StreamSubscription<Object?> listen(
    void Function(Object?)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _controller.stream.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
}
