import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../core/diagnostic_log.dart';

typedef DashboardStateProvider = Map<String, Object?> Function();
typedef DashboardActionHandler =
    Future<void> Function(String action, Map<String, dynamic> parameters);

class HostDashboardServer {
  HostDashboardServer({
    required this.stateProvider,
    required this.actionHandler,
  });

  static const int defaultPort = 47654;
  static const int _portAttempts = 8;

  final DashboardStateProvider stateProvider;
  final DashboardActionHandler actionHandler;
  HttpServer? _server;
  StreamSubscription<HttpRequest>? _subscription;

  int? get port => _server?.port;
  String? get url => port == null ? null : 'http://127.0.0.1:$port/';

  Future<void> start() async {
    if (_server != null) return;
    Object? lastError;
    for (var offset = 0; offset < _portAttempts; offset++) {
      final port = defaultPort + offset;
      try {
        final server = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          port,
          shared: false,
        );
        _server = server;
        _subscription = server.listen(
          (request) => unawaited(_handle(request)),
          onError: (Object error, StackTrace stackTrace) {
            unawaited(
              DiagnosticLog.record(
                'Dashboard Windows',
                'Falha no servidor web local.',
                error: error,
                stackTrace: stackTrace,
              ),
            );
          },
        );
        await DiagnosticLog.record(
          'Dashboard Windows',
          'Painel local ouvindo em http://127.0.0.1:$port/.',
        );
        return;
      } catch (error) {
        lastError = error;
      }
    }
    throw HttpException(
      'Não foi possível iniciar o painel localhost entre as portas '
      '$defaultPort e ${defaultPort + _portAttempts - 1}: $lastError',
    );
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    if (!_isLocalRequest(request)) {
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
      return;
    }
    request.response.headers
      ..set(HttpHeaders.cacheControlHeader, 'no-store')
      ..set('X-Content-Type-Options', 'nosniff')
      ..set(
        'Content-Security-Policy',
        "default-src 'none'; style-src 'self'; script-src 'self'; "
            "connect-src 'self'; img-src data:;",
      );

    final dashboardAsset = switch (request.uri.path) {
      '/assets/dashboard.css' => 'dashboard.css',
      '/assets/dashboard.js' => 'dashboard.js',
      _ => null,
    };
    if (request.method == 'GET' && dashboardAsset != null) {
      final asset = await rootBundle.load('assets/dashboard/$dashboardAsset');
      request.response
        ..headers.contentType = dashboardAsset.endsWith('.css')
            ? ContentType('text', 'css', charset: 'utf-8')
            : ContentType('application', 'javascript', charset: 'utf-8')
        ..add(
          asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes),
        );
      await request.response.close();
      return;
    }

    if (request.method == 'GET' && request.uri.path == '/') {
      request.response.headers.contentType = ContentType.html;
      request.response.write(
        await rootBundle.loadString('assets/dashboard/index.html'),
      );
      await request.response.close();
      return;
    }
    if (request.method == 'GET' && request.uri.path == '/api/status') {
      await _writeJson(request.response, HttpStatus.ok, stateProvider());
      return;
    }
    if (request.method == 'GET' && request.uri.path == '/api/diagnostics') {
      request.response.headers.contentType = ContentType.text;
      request.response.write(await DiagnosticLog.export());
      await request.response.close();
      return;
    }
    if (request.method == 'POST' && request.uri.path == '/api/action') {
      if (!_isTrustedBrowserPost(request)) {
        await _writeJson(request.response, HttpStatus.forbidden, {
          'error': 'Origem local inválida.',
        });
        return;
      }
      try {
        final body = await _readJsonBody(request);
        final action = body['action'];
        if (action is! String || action.length > 32) {
          throw const FormatException('Ação inválida.');
        }
        await actionHandler(action, body);
        await _writeJson(request.response, HttpStatus.ok, {'ok': true});
      } catch (error, stackTrace) {
        await DiagnosticLog.record(
          'Dashboard Windows',
          'Ação local recusada.',
          error: error,
          stackTrace: stackTrace,
        );
        await _writeJson(request.response, HttpStatus.badRequest, {
          'error': error.toString(),
        });
      }
      return;
    }
    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
  }

  bool _isLocalRequest(HttpRequest request) {
    final address = request.connectionInfo?.remoteAddress;
    final host = request.headers
        .value(HttpHeaders.hostHeader)
        ?.split(':')
        .first;
    return address?.isLoopback == true &&
        (host == '127.0.0.1' || host == 'localhost');
  }

  bool _isTrustedBrowserPost(HttpRequest request) {
    final origin = request.headers.value('origin');
    return origin == 'http://127.0.0.1:${_server?.port}' ||
        origin == 'http://localhost:${_server?.port}';
  }

  Future<Map<String, dynamic>> _readJsonBody(HttpRequest request) async {
    final body = StringBuffer();
    var byteLength = 0;
    await for (final chunk in request) {
      byteLength += chunk.length;
      if (byteLength > 4096) {
        throw const FormatException('Corpo da solicitação excede 4 KB.');
      }
      body.write(utf8.decode(chunk));
    }
    final decoded = jsonDecode(body.toString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('JSON da ação inválido.');
    }
    return decoded;
  }

  Future<void> _writeJson(
    HttpResponse response,
    int statusCode,
    Map<String, Object?> body,
  ) async {
    response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    await response.close();
  }
}
