import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_remote_server/src/host/host_dashboard.dart';
import 'package:open_remote_server/src/host/host_request_error.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HostDashboardServer dashboard;
  late HttpClient client;
  HttpOverrides? previousOverrides;
  final actions = <String>[];
  Object? refusal;

  setUp(() async {
    actions.clear();
    refusal = null;
    previousOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    client = HttpClient();
    dashboard = HostDashboardServer(
      stateProvider: () => {
        'running': true,
        'addresses': ['192.168.1.2'],
      },
      actionHandler: (action, _) async {
        if (refusal != null) throw refusal!;
        actions.add(action);
      },
      pairingQrProvider: () => 'open-remote-test-pairing',
    );
    await dashboard.start();
  });
  tearDown(() async {
    client.close(force: true);
    await dashboard.stop();
    HttpOverrides.global = previousOverrides;
  });

  Future<(HttpClientResponse, String)> get(String path) async {
    final request = await client.getUrl(Uri.parse('${dashboard.url}$path'));
    final response = await request.close();
    return (response, await utf8.decoder.bind(response).join());
  }

  test(
    'serves the dashboard and external assets with a compatible CSP',
    () async {
      final (response, html) = await get('');
      expect(response.statusCode, HttpStatus.ok);
      expect(
        response.headers.value('Content-Security-Policy'),
        contains("script-src 'self'"),
      );
      expect(
        html,
        contains('<script src="/assets/dashboard.js" defer></script>'),
      );
      expect(html, isNot(contains('<script>')));
      for (final path in [
        'assets/dashboard.js',
        'assets/dashboard.css',
        'assets/mark.svg',
      ]) {
        final (asset, body) = await get(path);
        expect(asset.statusCode, HttpStatus.ok, reason: path);
        expect(body, isNotEmpty, reason: path);
      }
      final (_, javascript) = await get('assets/dashboard.js');
      expect(
        javascript,
        await rootBundle.loadString('assets/dashboard/assets/dashboard.js'),
      );
    },
  );

  test('serves status and a pairing QR', () async {
    final (_, state) = await get('api/status');
    expect(jsonDecode(state)['running'], true);
    final (response, qr) = await get('api/pairing-qr.svg');
    expect(response.statusCode, HttpStatus.ok);
    expect(response.headers.contentType?.mimeType, 'image/svg+xml');
    expect(qr, contains('<svg'));
  });

  test('accepts local actions and rejects untrusted origins', () async {
    Future<int> action(String origin) async {
      final request = await client.postUrl(
        Uri.parse('${dashboard.url}api/action'),
      );
      request.headers.set('origin', origin);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'action': 'start'}));
      final response = await request.close();
      await response.drain<void>();
      return response.statusCode;
    }

    expect(await action('https://example.invalid'), HttpStatus.forbidden);
    expect(actions, isEmpty);
    expect(await action('http://127.0.0.1:${dashboard.port}'), HttpStatus.ok);
    expect(actions, ['start']);
  });

  test(
    'returns stable localization codes with compatible legacy errors',
    () async {
      Future<Map<String, dynamic>> post(Object body, {String? origin}) async {
        final request = await client.postUrl(
          Uri.parse('${dashboard.url}api/action'),
        );
        request.headers.set(
          'origin',
          origin ?? 'http://127.0.0.1:${dashboard.port}',
        );
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
        final response = await request.close();
        expect(response.statusCode, isNot(HttpStatus.ok));
        return jsonDecode(await utf8.decoder.bind(response).join())
            as Map<String, dynamic>;
      }

      for (final (body, code) in [
        (<String, Object?>{}, 'invalid_action'),
        (<Object?>[], 'invalid_body'),
        (<String, Object?>{'action': 'update_check'}, 'updates_unavailable'),
      ]) {
        final result = await post(body);
        expect(result['errorCode'], code);
        expect(result['error'], isA<String>());
      }
      final untrusted = await post({
        'action': 'start',
      }, origin: 'https://example.invalid');
      expect(untrusted['errorCode'], 'invalid_origin');
      expect(actions, isEmpty);
      refusal = const HostRequestError(
        'invalid_request',
        'Pedido de conexão inválido.',
      );
      final owned = await post({'action': 'approve', 'id': 'expired'});
      expect(owned['errorCode'], 'invalid_request');
      expect(owned['error'], contains('Pedido de conexão inválido.'));
      refusal = StateError('Technical diagnostic detail');
      final unexpected = await post({'action': 'start'});
      expect(unexpected['errorCode'], 'action_failed');
      expect(actions, isEmpty);
    },
  );
}
