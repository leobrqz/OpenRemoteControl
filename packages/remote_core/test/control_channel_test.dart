import 'dart:async';
import 'dart:typed_data';

import 'package:open_remote_core/open_remote_core.dart';
import 'package:test/test.dart';

class _Pipe {
  final _buffer = <int>[];
  Completer<void>? _changed;
  bool _closed = false;

  Future<void> write(List<int> bytes) async {
    _buffer.addAll(bytes);
    _changed?.complete();
    _changed = null;
  }

  Future<Uint8List?> read(int max) async {
    while (_buffer.isEmpty && !_closed) {
      _changed ??= Completer<void>();
      await _changed!.future;
    }
    if (_buffer.isEmpty) return null;
    final count = [max, 2, _buffer.length].reduce((a, b) => a < b ? a : b);
    final bytes = Uint8List.fromList(_buffer.take(count).toList());
    _buffer.removeRange(0, count);
    return bytes;
  }

  Future<void> close() async {
    _closed = true;
    _changed?.complete();
    _changed = null;
  }
}

void main() {
  test('exchanges ordered frames across fragmented byte streams', () async {
    final ab = _Pipe();
    final ba = _Pipe();
    final a = FramedControlChannel(
      read: ba.read,
      write: ab.write,
      release: ab.close,
    );
    final b = FramedControlChannel(
      read: ab.read,
      write: ba.write,
      release: ba.close,
    );
    final receivedByA = StreamIterator<Object?>(a);
    final receivedByB = StreamIterator<Object?>(b);
    a.add('first');
    a.add('segundo 🎵');
    b.add('response');
    expect(await receivedByB.moveNext(), isTrue);
    expect(receivedByB.current, 'first');
    expect(await receivedByB.moveNext(), isTrue);
    expect(receivedByB.current, 'segundo 🎵');
    expect(await receivedByA.moveNext(), isTrue);
    expect(receivedByA.current, 'response');
    await a.close();
    expect(await receivedByB.moveNext(), isFalse);
    await b.close();
    await receivedByA.cancel();
    await receivedByB.cancel();
  });

  test('rejects an oversized incoming frame before reading its body', () async {
    final input = _Pipe();
    var released = false;
    final channel = FramedControlChannel(
      read: input.read,
      write: (_) async {},
      release: () async {
        released = true;
        await input.close();
      },
    );
    final errors = <Object>[];
    final done = Completer<void>();
    channel.listen((_) {}, onError: errors.add, onDone: done.complete);
    await input.write([0, 1, 0, 0]);
    await done.future.timeout(const Duration(seconds: 2));
    expect(errors, hasLength(1));
    expect(errors.single, isA<FormatException>());
    expect(released, isTrue);
  });
}
