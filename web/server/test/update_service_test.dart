import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_remote_server/src/host/host_dashboard.dart';
import 'package:open_remote_server/src/updates/update_platform.dart';
import 'package:open_remote_server/src/updates/update_service.dart';

class FakeUpdater implements UpdatePlatform {
  final progress = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  bool managed = true;
  int checks = 0, downloads = 0, preparations = 0;
  Completer<Map<String, dynamic>?>? pendingCheck;
  Completer<void>? pendingDownload;
  String? failure;
  String version = '0.3.1';
  Map<String, dynamic> get candidate => {
    'version': version,
    'packageId': 'org.openremotecontrol.windows',
    'channel': 'win-x64',
    'notes': '<script>alert(1)</script>',
    'releaseUrl':
        'https://github.com/leobrqz/OpenRemoteControl/releases/tag/v$version',
  };
  @override
  Stream<Map<String, dynamic>> get events => progress.stream;
  @override
  Future<Map<String, dynamic>> getContext() async => {
    'managed': managed,
    'version': '0.3.0',
    'packageId': 'org.openremotecontrol.windows',
    'channel': 'win-x64',
  };
  @override
  Future<Map<String, dynamic>?> check() async {
    checks++;
    if (pendingCheck != null) return pendingCheck!.future;
    return candidate;
  }

  @override
  Future<void> download() async {
    downloads++;
    if (failure != null && failure != 'prepare_failed') {
      throw PlatformException(code: failure!);
    }
    if (pendingDownload != null) await pendingDownload!.future;
  }

  @override
  Future<void> prepareApply() async {
    preparations++;
    if (failure == 'prepare_failed') throw PlatformException(code: failure!);
  }
}

Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeUpdater adapter;
  late UpdateService service;
  var shutdowns = 0;
  setUp(() async {
    adapter = FakeUpdater();
    shutdowns = 0;
    service = UpdateService(
      platform: adapter,
      shutdown: () async {
        shutdowns++;
      },
    );
    await service.initialize();
  });
  tearDown(() async {
    service.dispose();
    await adapter.progress.close();
  });
  Future<String> available() async {
    service.check();
    await tick();
    expect(service.state, 'available');
    return service.snapshot['candidateId'] as String;
  }

  test(
    'one asynchronous automatic check, deferral and fresh manual approval',
    () async {
      adapter.pendingCheck = Completer();
      await service.checkAfterStartup();
      await service.checkAfterStartup();
      expect(service.state, 'checking');
      expect(adapter.checks, 1);
      expect(service.check, throwsA(isA<UpdateConflict>()));
      expect(service.snapshot['candidateId'], isNull);
      adapter.pendingCheck!.complete(adapter.candidate);
      await tick();
      final first = service.snapshot['candidateId'] as String;
      service.defer(first);
      expect(service.state, 'deferred');
      expect(service.trayVersion, isNull);
      expect(adapter.downloads, 0);
      expect(shutdowns, 0);
      expect(() => service.install(first), throwsA(isA<UpdateConflict>()));
      adapter.pendingCheck = null;
      final next = await available();
      expect(next, isNot(first));
      expect(() => service.install(first), throwsA(isA<UpdateConflict>()));
    },
  );
  test(
    'consent survives browser closure; progress is bounded and shutdown follows validation',
    () async {
      final id = await available();
      adapter.pendingDownload = Completer();
      service.install(id);
      expect(service.state, 'downloading');
      expect(() => service.install(id), throwsA(isA<UpdateConflict>()));
      expect(() => service.defer(id), throwsA(isA<UpdateConflict>()));
      expect(service.check, throwsA(isA<UpdateConflict>()));
      adapter.progress.add({'type': 'progress', 'percent': 110});
      expect(service.snapshot['progressPercent'], 100);
      expect(adapter.preparations, 0);
      expect(shutdowns, 0);
      adapter.pendingDownload!.complete();
      await tick();
      expect(service.state, 'applying');
      expect(service.snapshot['progressPercent'], isNull);
      await Future<void>.delayed(const Duration(milliseconds: 1250));
      expect(shutdowns, 1);
      expect(adapter.downloads, 1);
    },
  );
  for (final code in [
    'timeout',
    'offline',
    'rate_limited',
    'missing_asset',
    'invalid_metadata',
    'checksum',
    'insufficient_space',
    'unwritable_directory',
    'prepare_failed',
  ]) {
    test('$code retains host and retry needs a new approval', () async {
      final id = await available();
      adapter.failure = code;
      service.install(id);
      await tick();
      expect(service.state, 'failed');
      expect(service.snapshot['error'], containsPair('code', code));
      expect(service.snapshot['candidateId'], isNull);
      expect(shutdowns, 0);
      expect(() => service.install(id), throwsA(isA<UpdateConflict>()));
      adapter.failure = null;
      await available();
      expect(adapter.downloads, 1);
    });
  }
  for (final version in ['0.3.0', '0.2.1', '0.3.1-beta', 'bad']) {
    test('rejects non-new stable version $version', () async {
      adapter.version = version;
      service.check();
      await tick();
      expect(service.state, 'failed');
      expect(adapter.downloads, 0);
    });
  }
  test('unmanaged installation disables every operation', () async {
    service.dispose();
    adapter.managed = false;
    service = UpdateService(
      platform: adapter,
      shutdown: () async {
        shutdowns++;
      },
    );
    await service.checkAfterStartup();
    expect(service.state, 'disabled');
    expect(adapter.checks, 0);
    expect(service.check, throwsA(isA<UpdateConflict>()));
  });
  test('restart never reuses consent or automatically downloads', () async {
    await available();
    service.dispose();
    service = UpdateService(
      platform: adapter,
      shutdown: () async {
        shutdowns++;
      },
    );
    await service.checkAfterStartup();
    await tick();
    expect(service.state, 'available');
    expect(adapter.downloads, 0);
  });
  test(
    'loopback API returns promptly, rejects foreign origins, stale IDs and duplicate operations',
    () async {
      final overrides = HttpOverrides.current;
      HttpOverrides.global = null;
      final client = HttpClient();
      final dashboard = HostDashboardServer(
        stateProvider: () => {'running': true},
        actionHandler: (_, _) async {},
        pairingQrProvider: () => null,
        updates: service,
      );
      await dashboard.start();
      Future<int> post(
        Map<String, Object?> data, {
        bool foreign = false,
      }) async {
        final request = await client.postUrl(
          Uri.parse('${dashboard.url}api/action'),
        );
        request.headers.set(
          'Origin',
          foreign
              ? 'https://evil.invalid'
              : 'http://127.0.0.1:${dashboard.port}',
        );
        request.write(jsonEncode(data));
        final response = await request.close();
        await response.drain<void>();
        return response.statusCode;
      }

      try {
        adapter.pendingCheck = Completer();
        expect(await post({'action': 'update_check'}, foreign: true), 403);
        expect(adapter.checks, 0);
        expect(
          await post({'action': 'update_check', 'url': 'https://evil.invalid'}),
          400,
        );
        expect(await post({'action': 'update_check'}), 202);
        expect(await post({'action': 'update_check'}), 409);
        final status = await client.getUrl(
          Uri.parse('${dashboard.url}api/status'),
        );
        final response = await status.close();
        expect(
          jsonDecode(await utf8.decoder.bind(response).join())['running'],
          true,
        );
        adapter.pendingCheck!.complete(adapter.candidate);
        await tick();
        expect(
          await post({'action': 'update_install', 'candidateId': 'old'}),
          409,
        );
        expect(await post({'action': 'update_install'}), 400);
        adapter.pendingDownload = Completer();
        final id = service.snapshot['candidateId'];
        final clicks = await Future.wait(
          List.generate(
            3,
            (_) => post({'action': 'update_install', 'candidateId': id}),
          ),
        );
        expect(clicks.where((code) => code == 202).length, 1);
        expect(clicks.where((code) => code == 409).length, 2);
        expect(adapter.downloads, 1);
        adapter.pendingDownload!.completeError(
          PlatformException(code: 'checksum'),
        );
        await tick();
        final request = await client.getUrl(
          Uri.parse('${dashboard.url}api/updates'),
        );
        final update = await request.close();
        expect(
          jsonDecode(await utf8.decoder.bind(update).join())['state'],
          'failed',
        );
      } finally {
        client.close(force: true);
        await dashboard.stop();
        HttpOverrides.global = overrides;
      }
    },
  );
  test('native adapter never accepts browser-supplied paths or URLs', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('open_remote/updater'), (
          call,
        ) async {
          calls.add(call);
          return call.method == 'getContext'
              ? {'managed': false, 'version': '0.3.0'}
              : null;
        });
    final native = NativeUpdatePlatform();
    await native.getContext();
    await native.check();
    await native.download();
    await native.prepareApply();
    expect(calls.map((call) => call.method), [
      'getContext',
      'check',
      'download',
      'prepareApply',
    ]);
    expect(calls.every((call) => call.arguments == null), true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('open_remote/updater'),
          null,
        );
  });
}
