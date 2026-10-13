import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_remote_control/src/client/updates/android_update_card.dart';
import 'package:open_remote_control/src/client/updates/android_update_controller.dart';
import 'package:open_remote_control/src/client/updates/android_update_models.dart';
import 'package:open_remote_control/src/client/updates/android_update_platform.dart';
import 'package:open_remote_control/src/client/updates/android_update_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'shows installed and available versions, notes and size without downloading',
    (tester) async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);

      await _pumpPage(tester, fixture.controller);

      expect(find.textContaining('1.0.0'), findsOneWidget);
      expect(find.textContaining('1.1.0'), findsOneWidget);
      expect(
        find.text('Corrections, mouse improvements, and stability fixes.'),
        findsOneWidget,
      );
      expect(find.textContaining('2,5 MB'), findsOneWidget);
      expect(fixture.platform.downloadCalls, 0);
      expect(find.text('Atualizar'), findsOneWidget);
    },
  );

  testWidgets(
    'approval starts one download; progress is shown and cancel works',
    (tester) async {
      final fixture = await _Fixture.create(downloadGate: Completer<void>());
      addTearDown(fixture.dispose);
      await _pumpPage(tester, fixture.controller);

      await tester.tap(find.text('Atualizar'));
      await tester.pump();
      expect(fixture.platform.downloadCalls, 1);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      fixture.platform.emit(
        AndroidUpdateSnapshot(
          state: AndroidUpdateState.downloading,
          receivedBytes: 7,
          totalBytes: 10,
          candidate: fixture.candidate,
        ),
      );
      await tester.pump();
      expect(find.text('70%'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pump();
      expect(fixture.platform.cancelCalls, 1);
      expect(fixture.controller.state, AndroidUpdateState.cancelled);
      expect(fixture.controller.candidate, isNull);

      fixture.platform.downloadGate!.complete();
      await tester.pumpAndSettle();
      expect(fixture.platform.downloadCalls, 1);
    },
  );

  testWidgets('Agora não hides the notice until a manual check', (
    tester,
  ) async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.dispose);
    await _pumpPage(tester, fixture.controller, includeNotice: true);

    expect(find.textContaining('Atualização 1.1.0 disponível'), findsOneWidget);
    final noticeDismiss = find.descendant(
      of: find.byType(AndroidUpdateNotice),
      matching: find.text('Agora não'),
    );
    await tester.tap(noticeDismiss);
    await tester.pumpAndSettle();
    expect(fixture.controller.state, AndroidUpdateState.deferred);
    expect(find.textContaining('Atualização 1.1.0 disponível'), findsNothing);

    await tester.tap(find.text('Verificar atualizações'));
    await tester.pumpAndSettle();
    expect(fixture.controller.state, AndroidUpdateState.available);
    expect(find.textContaining('Atualização 1.1.0 disponível'), findsOneWidget);
  });

  testWidgets('ready state only offers installation, not another download', (
    tester,
  ) async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.dispose);
    fixture.platform.emit(
      AndroidUpdateSnapshot(
        state: AndroidUpdateState.ready,
        receivedBytes: fixture.candidate.size,
        totalBytes: fixture.candidate.size,
        candidate: fixture.candidate,
      ),
    );
    await _pumpPage(tester, fixture.controller);

    expect(find.text('Instalar atualização'), findsOneWidget);
    expect(find.text('Atualizar'), findsNothing);
    expect(find.text('Verificar atualizações'), findsNothing);
    expect(fixture.platform.downloadCalls, 0);
  });

  testWidgets(
    'permission state explains access and opens settings only on tap',
    (tester) async {
      final fixture = await _Fixture.create(askPermissionOnFirstInstall: true);
      addTearDown(fixture.dispose);
      fixture.platform.emit(
        AndroidUpdateSnapshot(
          state: AndroidUpdateState.ready,
          receivedBytes: fixture.candidate.size,
          totalBytes: fixture.candidate.size,
          candidate: fixture.candidate,
        ),
      );
      await _pumpPage(tester, fixture.controller);

      await tester.tap(find.text('Instalar atualização'));
      await tester.pumpAndSettle();
      expect(fixture.controller.state, AndroidUpdateState.permissionRequired);
      expect(
        find.textContaining('permita que o Open Remote Control instale'),
        findsOneWidget,
      );
      expect(fixture.platform.permissionCalls, 0);

      await tester.tap(find.text('Permitir instalação'));
      await tester.pumpAndSettle();
      expect(fixture.platform.permissionCalls, 1);
      expect(fixture.controller.state, AndroidUpdateState.ready);

      await tester.tap(find.text('Instalar atualização'));
      await tester.pumpAndSettle();
      expect(fixture.platform.installCalls, 2);
      expect(fixture.controller.state, AndroidUpdateState.installing);
      expect(fixture.platform.permissionCalls, 1);
    },
  );

  testWidgets('failed check can be retried manually from the card', (
    tester,
  ) async {
    final fixture = await _Fixture.create(failFirstCheck: true);
    addTearDown(fixture.dispose);
    await _pumpPage(tester, fixture.controller);

    expect(fixture.controller.state, AndroidUpdateState.failed);
    expect(find.text('Tentar novamente'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(fixture.repository.calls, 2);
    expect(fixture.controller.state, AndroidUpdateState.available);
    expect(fixture.platform.downloadCalls, 0);
  });

  testWidgets('card fits a 360 px viewport without overflow', (tester) async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.dispose);
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpPage(tester, fixture.controller);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(AndroidUpdateCard), findsOneWidget);
  });
}

Future<void> _pumpPage(
  WidgetTester tester,
  AndroidUpdateController controller, {
  bool includeNotice = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Scaffold(
          body: Column(
            children: [
              if (includeNotice)
                AndroidUpdateNotice(controller: controller, onDetails: () {}),
              Expanded(
                child: SingleChildScrollView(
                  child: AndroidUpdateCard(controller: controller),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

class _Fixture {
  _Fixture({
    required this.repository,
    required this.platform,
    required this.controller,
    required this.candidate,
  });

  final _FakeRepository repository;
  final _FakePlatform platform;
  final AndroidUpdateController controller;
  final AndroidUpdateCandidate candidate;

  static Future<_Fixture> create({
    Completer<void>? downloadGate,
    bool failFirstCheck = false,
    bool askPermissionOnFirstInstall = false,
  }) async {
    final candidate = _candidate();
    final repository = _FakeRepository(
      candidate,
      failFirstCheck: failFirstCheck,
    );
    final platform = _FakePlatform(
      downloadGate: downloadGate,
      askPermissionOnFirstInstall: askPermissionOnFirstInstall,
    );
    final controller = AndroidUpdateController(
      repository: repository,
      platform: platform,
    );
    await controller.initialize();
    await controller.check(manual: true);
    return _Fixture(
      repository: repository,
      platform: platform,
      controller: controller,
      candidate: candidate,
    );
  }

  Future<void> dispose() async {
    controller.dispose();
    await platform.eventsController.close();
  }
}

AndroidUpdateCandidate _candidate() => AndroidUpdateCandidate(
  packageName: AndroidUpdateRepository.packageName,
  versionName: '1.1.0',
  versionCode: 11,
  minSdk: 23,
  targetSdk: 35,
  maxSdk: null,
  abis: const [],
  signerSha256: [List.filled(64, 'a').join()],
  assetName: AndroidUpdateRepository.apkName,
  size: 2621440,
  sha256: List.filled(64, 'c').join(),
  downloadUrl:
      'https://github.com/leobrqz/OpenRemoteControl/releases/download/v1.1.0/${AndroidUpdateRepository.apkName}',
  notes: 'Corrections, mouse improvements, and stability fixes.',
  releaseUrl:
      'https://github.com/leobrqz/OpenRemoteControl/releases/tag/v1.1.0',
);

class _FakeRepository implements AndroidUpdateRepository {
  _FakeRepository(this.candidate, {this.failFirstCheck = false});

  final AndroidUpdateCandidate candidate;
  final bool failFirstCheck;
  int calls = 0;

  @override
  Future<AndroidUpdateCheckResult> check(AndroidUpdateDeviceInfo device) async {
    calls++;
    if (failFirstCheck && calls == 1) {
      throw const AndroidUpdateException('network');
    }
    return AndroidUpdateCheckResult(candidate: candidate);
  }
}

class _FakePlatform implements AndroidUpdatePlatform {
  _FakePlatform({this.downloadGate, this.askPermissionOnFirstInstall = false});

  final Completer<void>? downloadGate;
  final bool askPermissionOnFirstInstall;
  final eventsController = StreamController<AndroidUpdateSnapshot>.broadcast();
  AndroidUpdateSnapshot _snapshot = const AndroidUpdateSnapshot(
    state: AndroidUpdateState.idle,
    receivedBytes: 0,
    totalBytes: 0,
  );
  int downloadCalls = 0;
  int cancelCalls = 0;
  int installCalls = 0;
  int permissionCalls = 0;

  @override
  Stream<AndroidUpdateSnapshot> get events => eventsController.stream;

  @override
  Future<AndroidUpdateDeviceInfo> getDeviceInfo() async =>
      AndroidUpdateDeviceInfo(
        packageName: AndroidUpdateRepository.packageName,
        versionName: '1.0.0',
        versionCode: 10,
        sdkInt: 35,
        abis: const ['arm64-v8a'],
        signerSha256: [List.filled(64, 'a').join()],
      );

  @override
  Future<AndroidUpdateSnapshot> getState() async => _snapshot;

  @override
  Future<void> download(
    AndroidUpdateCandidate candidate, {
    required Map<String, String> notification,
  }) {
    downloadCalls++;
    return downloadGate?.future ?? Future<void>.value();
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    emit(
      const AndroidUpdateSnapshot(
        state: AndroidUpdateState.cancelled,
        receivedBytes: 0,
        totalBytes: 0,
      ),
    );
  }

  @override
  Future<bool> canInstall() async => true;

  @override
  Future<void> openInstallPermission() async {
    permissionCalls++;
    emit(
      AndroidUpdateSnapshot(
        state: AndroidUpdateState.ready,
        receivedBytes: 2621440,
        totalBytes: 2621440,
        candidate: _candidate(),
      ),
    );
  }

  @override
  Future<void> install() async {
    installCalls++;
    final state = askPermissionOnFirstInstall && installCalls == 1
        ? AndroidUpdateState.permissionRequired
        : AndroidUpdateState.installing;
    emit(
      AndroidUpdateSnapshot(
        state: state,
        receivedBytes: 2621440,
        totalBytes: 2621440,
      ),
    );
  }

  void emit(AndroidUpdateSnapshot snapshot) {
    _snapshot = snapshot;
    eventsController.add(snapshot);
  }
}
