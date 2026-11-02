import 'dart:async';

/// Serializes complete batches so secure sequence numbers match wire order.
class OrderedSender {
  OrderedSender(this.sendOne);

  final Future<void> Function(Map<String, Object?>) sendOne;
  Future<void> _tail = Future<void>.value();

  Future<void> send(List<Map<String, Object?>> messages) {
    final operation = _tail.then((_) async {
      for (final message in messages) {
        await sendOne(message);
      }
    });
    _tail = operation;
    return operation;
  }
}
