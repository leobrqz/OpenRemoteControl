import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:open_remote_core/open_remote_core.dart';
import 'pairing_qr_svg.dart';
import 'host_request_error.dart';
import '../updates/update_service.dart';

typedef DashboardStateProvider = Map<String, Object?> Function();
typedef DashboardActionHandler =
    Future<void> Function(String action, Map<String, dynamic> parameters);
typedef DashboardPairingQrProvider = String? Function();

class HostDashboardServer {
  HostDashboardServer({
    required this.stateProvider,
    required this.actionHandler,
    required this.pairingQrProvider,
    this.updates,
  });

  static const int defaultPort = 47654;
  static const int _portAttempts = 8;

  final DashboardStateProvider stateProvider;
  final DashboardActionHandler actionHandler;
  final DashboardPairingQrProvider pairingQrProvider;
  final UpdateService? updates;
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
            "connect-src 'self'; img-src 'self' data:;",
      );

    final dashboardAsset = switch (request.uri.path) {
      '/assets/dashboard.css' => 'assets/dashboard/assets/dashboard.css',
      '/assets/dashboard.js' => 'assets/dashboard/assets/dashboard.js',
      '/assets/mark.svg' || '/favicon.ico' => 'assets/branding/mark.svg',
      _ => null,
    };
    if (request.method == 'GET' && dashboardAsset != null) {
      final asset = await rootBundle.load(dashboardAsset);
      request.response
        ..headers.contentType = dashboardAsset.endsWith('.css')
            ? ContentType('text', 'css', charset: 'utf-8')
            : dashboardAsset.endsWith('.svg')
            ? ContentType('image', 'svg+xml', charset: 'utf-8')
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
    if (request.method == 'GET' && request.uri.path == '/api/updates') {
      await _writeJson(
        request.response,
        HttpStatus.ok,
        updates?.snapshot ?? {'state': 'disabled'},
      );
      return;
    }
    if (request.method == 'GET' && request.uri.path == '/api/pairing-qr.svg') {
      final payload = pairingQrProvider();
      if (payload == null) {
        request.response.statusCode = HttpStatus.gone;
        await request.response.close();
        return;
      }
      request.response
        ..headers.contentType = ContentType(
          'image',
          'svg+xml',
          charset: 'utf-8',
        )
        ..headers.set(HttpHeaders.cacheControlHeader, 'private, max-age=60')
        ..write(PairingQrSvg.render(payload));
      await request.response.close();
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
          'errorCode': 'invalid_origin',
        });
        return;
      }
      try {
        final body = await _readJsonBody(request);
        final action = body['action'];
        if (action is! String || action.length > 32) {
          throw const HostRequestError('invalid_action', 'Ação inválida.');
        }
        var status = HttpStatus.ok;
        if (action.startsWith('update_')) {
          final updater = updates;
          if (updater == null) {
            throw const UpdateConflict(
              'Atualizações indisponíveis.',
              code: 'updates_unavailable',
            );
          }
          final expected = action == 'update_check'
              ? {'action'}
              : {'action', 'candidateId'};
          if (body.keys.any((key) => !expected.contains(key))) {
            throw const HostRequestError(
              'invalid_update',
              'Parâmetros de atualização inválidos.',
            );
          }
          switch (action) {
            case 'update_check':
              updater.check();
              status = HttpStatus.accepted;
            case 'update_defer':
            case 'update_install':
              final id = body['candidateId'];
              if (id is! String || id.isEmpty || id.length > 64) {
                throw const HostRequestError(
                  'invalid_update',
                  'Identificador de atualização inválido.',
                );
              }
              if (action == 'update_defer') {
                updater.defer(id);
              } else {
                updater.install(id);
                status = HttpStatus.accepted;
              }
            default:
              throw const HostRequestError(
                'unknown_action',
                'Ação de atualização desconhecida.',
              );
          }
        } else {
          await actionHandler(action, body);
        }
        await _writeJson(request.response, status, {'ok': true});
      } catch (error, stackTrace) {
        await DiagnosticLog.record(
          'Dashboard Windows',
          'Ação local recusada.',
          error: error,
          stackTrace: stackTrace,
        );
        await _writeJson(
          request.response,
          error is UpdateConflict ? HttpStatus.conflict : HttpStatus.badRequest,
          {
            'error': error.toString(),
            'errorCode': switch (error) {
              HostRequestError() => error.code,
              UpdateConflict() => error.code,
              FormatException() => 'invalid_body',
              _ => 'action_failed',
            },
          },
        );
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
        throw const HostRequestError(
          'invalid_body',
          'Corpo da solicitação excede 4 KB.',
        );
      }
      body.write(utf8.decode(chunk));
    }
    final decoded = jsonDecode(body.toString());
    if (decoded is! Map<String, dynamic>) {
      throw const HostRequestError('invalid_body', 'JSON da ação inválido.');
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
