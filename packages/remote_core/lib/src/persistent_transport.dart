import 'dart:async';
import 'dart:convert';

import 'package:iroh_quic/iroh_quic.dart';

import 'control_channel.dart';
import 'wire.dart';

final _protocol = utf8.encode('open-remote/control/1');
Future<void>? _initializing;

Future<void> _initialize() {
  final existing = _initializing;
  if (existing != null) return existing;
  final initialization = Iroh.init();
  _initializing = initialization;
  return initialization.catchError((Object error, StackTrace stack) {
    _initializing = null;
    Error.throwWithStackTrace(error, stack);
  });
}

Future<ControlChannel> connectPersistent(String address) async {
  await _initialize();
  final id = PublicKey.fromBytes(decodeBytes(address, exactLength: 32));
  final endpoint = await Endpoint.bind();
  Connection? connection;
  try {
    connection = await endpoint
        .connect(EndpointAddr(id), _protocol)
        .timeout(const Duration(seconds: 20));
    final (send, receive) = await connection.openBi().timeout(
      const Duration(seconds: 8),
    );
    return _channel(connection, send, receive, endpoint: endpoint);
  } catch (_) {
    connection?.close();
    await endpoint.close();
    rethrow;
  }
}

ControlChannel _channel(
  Connection connection,
  SendStream send,
  RecvStream receive, {
  Endpoint? endpoint,
}) => FramedControlChannel(
  read: receive.read,
  write: send.writeAll,
  release: () async {
    try {
      await send.finish();
    } catch (_) {}
    try {
      await receive.stop(0);
    } catch (_) {}
    connection.close();
    await endpoint?.close();
  },
);

/// An inbound endpoint whose stable identity is stored by the host.
class PersistentHostListener {
  PersistentHostListener._(this._endpoint, this._onChannel) {
    _accepting = _accept();
  }

  static Future<PersistentHostListener> bind(
    List<int> secret,
    Future<void> Function(ControlChannel channel) onChannel,
  ) async {
    await _initialize();
    final endpoint = await Endpoint.bind(
      secretKey: SecretKey.fromBytes(secret),
      alpns: [_protocol],
    );
    return PersistentHostListener._(endpoint, onChannel);
  }

  final Endpoint _endpoint;
  final Future<void> Function(ControlChannel channel) _onChannel;
  late final Future<void> _accepting;
  bool _closed = false;
  int _active = 0;

  String get address => encodeBytes(_endpoint.id.asBytes());

  Future<void> _accept() async {
    while (!_closed) {
      Connection? connection;
      try {
        connection = await _endpoint.accept();
        if (connection == null) return;
        if (_closed || _active >= 32) {
          connection.close();
          continue;
        }
        _active++;
        unawaited(_serve(connection));
      } catch (_) {
        connection?.close();
        if (!_closed) await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
  }

  Future<void> _serve(Connection connection) async {
    ControlChannel? channel;
    try {
      final (send, receive) = await connection.acceptBi().timeout(
        const Duration(seconds: 10),
      );
      channel = _channel(connection, send, receive);
      await _onChannel(channel);
    } catch (_) {
      connection.close();
    } finally {
      if (channel != null) {
        try {
          await channel.close();
        } catch (_) {}
      }
      _active--;
    }
  }

  Future<void> close() async {
    _closed = true;
    await _endpoint.close();
    await _accepting;
  }
}
