import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_remote_control/src/client/updates/android_update_controller.dart';
import 'package:open_remote_control/src/client/updates/android_update_models.dart';
import 'package:open_remote_control/src/client/updates/android_update_platform.dart';
import 'package:open_remote_control/src/client/updates/android_update_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'automatic check is single flight; defer suppresses reminders until manual check',
    () async {
      final repo = _FakeRepository(_candidate());
      final platform = _FakePlatform();
      final controller = AndroidUpdateController(
        repository: repo,
        platform: platform,
      );

      await controller.initialize();
      await Future<void>.delayed(Duration.zero);
      expect(repo.calls, 1);
      expect(controller.available, isTrue);
      expect(controller.currentVersion, '1.0.0');
      expect(controller.progress, 0);

      controller.defer();
      expect(controller.state, AndroidUpdateState.deferred);
      expect(controller.showReminder, isFalse);
      await controller.check();
      expect(repo.calls, 1);

      await controller.check(manual: true);
      expect(repo.calls, 2);
      expect(controller.state, AndroidUpdateState.available);
      expect(controller.showReminder, isTrue);
      controller.dispose();
    },
  );

  test(
    'duplicate checks share one request and disposal does not cancel transfer',
    () async {
      final pending = Completer<AndroidUpdateCheckResult>();
      final repo = _FakeRepository(_candidate(), gate: pending);
      final platform = _FakePlatform();
      final controller = AndroidUpdateController(
        repository: repo,
        platform: platform,
      );

      await controller.initialize();
      final manual = controller.check(manual: true);
      expect(repo.calls, 1);
      pending.complete(AndroidUpdateCheckResult(candidate: _candidate()));
      await manual;
      expect(controller.available, isTrue);

      controller.dispose();
      expect(platform.cancelCalls, 0);
    },
  );

  test(
    'approves one native download and exposes cancel and install permission actions',
    () async {
      final platform = _FakePlatform(downloadGate: Completer<void>());
      final controller = AndroidUpdateController(
        repository: _FakeRepository(_candidate()),
        platform: platform,
      );
      await controller.initialize();
      await Future<void>.delayed(Duration.zero);

      final labels = {
        'title': 'Atualização',
        'downloading': 'Baixando',
        'validating': 'Validando',
        'ready': 'Pronta',
        'cancel': 'Cancelar',
        'channelName': 'Atualizações',
      };
      final firstApproval = controller.approveDownload(notification: labels);
      await controller.approveDownload(notification: labels);
      expect(platform.downloadCalls, 1);
      expect(platform.lastNotification, labels);
      expect(platform.lastCandidate?.versionCode, 11);

      platform.downloadGate!.complete();
      await firstApproval;
      await controller.cancel();
      expect(platform.cancelCalls, 1);

      await controller.openInstallPermission();
      expect(platform.permissionCalls, 1);
      platform.installError = PlatformException(code: 'permission');
      await controller.install();
      expect(controller.errorCode, 'permission');
      controller.dispose();
    },
  );

  test('restores native ready state and skips the launch check', () async {
    final candidate = _candidate();
    final platform = _FakePlatform(
      initialSnapshot: AndroidUpdateSnapshot(
        state: AndroidUpdateState.ready,
        receivedBytes: candidate.size,
        totalBytes: candidate.size,
        candidate: candidate,
      ),
    );
    final repo = _FakeRepository(null);
    final controller = AndroidUpdateController(
      repository: repo,
      platform: platform,
    );

    await controller.initialize();
    await Future<void>.delayed(Duration.zero);
    expect(repo.calls, 0);
    expect(controller.state, AndroidUpdateState.ready);
    expect(controller.candidate?.versionName, candidate.versionName);
    controller.dispose();
  });

  test(
    'active and retryable installer snapshots block checks without resetting progress',
    () async {
      for (final state in [
        AndroidUpdateState.downloading,
        AndroidUpdateState.permissionRequired,
        AndroidUpdateState.installationCancelled,
      ]) {
        final candidate = _candidate();
        final platform = _FakePlatform(
          initialSnapshot: AndroidUpdateSnapshot(
            state: state,
            receivedBytes: 50,
            totalBytes: 100,
            candidate: candidate,
          ),
        );
        final repo = _FakeRepository(null);
        final controller = AndroidUpdateController(
          repository: repo,
          platform: platform,
        );

        await controller.initialize();
        await Future<void>.delayed(Duration.zero);

        expect(repo.calls, 0, reason: 'state=$state');
        expect(controller.state, state);
        expect(controller.progress, .5);
        expect(controller.candidate, same(candidate));
        controller.dispose();
      }
    },
  );

  test(
    'concurrent checks share device info loading before the first check',
    () async {
      final infoGate = Completer<AndroidUpdateDeviceInfo>();
      final platform = _FakePlatform(deviceInfoGate: infoGate);
      final repo = _FakeRepository(_candidate());
      final controller = AndroidUpdateController(
        repository: repo,
        platform: platform,
      );

      final first = controller.check();
      final second = controller.check(manual: true);
      expect(platform.deviceInfoCalls, 1);
      infoGate.complete(_deviceInfo());
      await Future.wait([first, second]);

      expect(repo.calls, 1);
      expect(controller.state, AndroidUpdateState.available);
      expect(platform.eventsAccessedAfterDeviceInfo, isTrue);
      controller.dispose();
    },
  );

  test(
    'idle snapshots preserve available and deferred states; cancel clears candidate',
    () async {
      final platform = _FakePlatform();
      final controller = AndroidUpdateController(
        repository: _FakeRepository(_candidate()),
        platform: platform,
      );
      await controller.initialize();
      await Future<void>.delayed(Duration.zero);

      platform.eventsController.add(
        const AndroidUpdateSnapshot(
          state: AndroidUpdateState.idle,
          receivedBytes: 0,
          totalBytes: 0,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.state, AndroidUpdateState.available);
      expect(controller.showReminder, isTrue);

      controller.defer();
      platform.eventsController.add(
        const AndroidUpdateSnapshot(
          state: AndroidUpdateState.idle,
          receivedBytes: 0,
          totalBytes: 0,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.state, AndroidUpdateState.deferred);
      expect(controller.available, isFalse);

      await controller.check(manual: true);
      expect(controller.available, isTrue);
      await controller.approveDownload(notification: const {});
      await controller.cancel();
      expect(platform.cancelCalls, 1);
      expect(controller.candidate, isNull);
      expect(controller.state, AndroidUpdateState.cancelled);
      expect(controller.available, isFalse);

      final staleCandidate = _candidate();
      platform.eventsController.add(
        AndroidUpdateSnapshot(
          state: AndroidUpdateState.ready,
          receivedBytes: staleCandidate.size,
          totalBytes: staleCandidate.size,
          candidate: staleCandidate,
        ),
      );
      platform.eventsController.add(
        const AndroidUpdateSnapshot(
          state: AndroidUpdateState.idle,
          receivedBytes: 0,
          totalBytes: 0,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.state, AndroidUpdateState.cancelled);
      expect(controller.candidate, isNull);

      await controller.check(manual: true);
      expect(controller.state, AndroidUpdateState.available);
      expect(controller.available, isTrue);
      controller.dispose();
    },
  );

  test('cancel before an approved download is a no-op', () async {
    final platform = _FakePlatform();
    final controller = AndroidUpdateController(
      repository: _FakeRepository(_candidate()),
      platform: platform,
    );
    await controller.initialize();
    await Future<void>.delayed(Duration.zero);

    await controller.cancel();

    expect(platform.cancelCalls, 0);
    expect(controller.available, isTrue);
    expect(controller.candidate, isNotNull);
    controller.dispose();
  });

  test(
    'default channel initialization handles missing native plugin',
    () async {
      final controller = AndroidUpdateController(
        repository: _FakeRepository(null),
      );

      await expectLater(controller.initialize(), completes);
      expect(controller.currentVersion, isNull);
      expect(controller.errorCode, 'unavailable');
      controller.dispose();
    },
  );

  test(
    'native events retain the approved candidate and update normalized progress',
    () async {
      final platform = _FakePlatform();
      final controller = AndroidUpdateController(
        repository: _FakeRepository(null),
        platform: platform,
      );
      await controller.initialize();
      await Future<void>.delayed(Duration.zero);
      final candidate = _candidate();
      platform.eventsController.add(
        AndroidUpdateSnapshot(
          state: AndroidUpdateState.downloading,
          receivedBytes: 140,
          totalBytes: 100,
          candidate: candidate,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.progress, 1);
      expect(controller.candidate, candidate);
      expect(controller.state, AndroidUpdateState.downloading);

      platform.eventsController.add(
        const AndroidUpdateSnapshot(
          state: AndroidUpdateState.ready,
          receivedBytes: 100,
          totalBytes: 100,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.candidate, candidate);
      expect(controller.state, AndroidUpdateState.ready);

      platform.eventsController.add(
        const AndroidUpdateSnapshot(
          state: AndroidUpdateState.downloading,
          receivedBytes: 40,
          totalBytes: 100,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.state, AndroidUpdateState.ready);
      expect(controller.progress, 1);
      controller.dispose();
    },
  );
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
  size: 1234,
  sha256: List.filled(64, 'c').join(),
  downloadUrl:
      'https://github.com/leobrqz/OpenRemoteControl/releases/download/v1.1.0/${AndroidUpdateRepository.apkName}',
  notes: 'Release notes',
  releaseUrl:
      'https://github.com/leobrqz/OpenRemoteControl/releases/tag/v1.1.0',
);

class _FakeRepository implements AndroidUpdateRepository {
  _FakeRepository(this.candidate, {this.gate});
  final AndroidUpdateCandidate? candidate;
  final Completer<AndroidUpdateCheckResult>? gate;
  int calls = 0;

  @override
  Future<AndroidUpdateCheckResult> check(AndroidUpdateDeviceInfo device) {
    calls++;
    if (gate != null) return gate!.future;
    return Future.value(AndroidUpdateCheckResult(candidate: candidate));
  }
}

class _FakePlatform implements AndroidUpdatePlatform {
  _FakePlatform({this.downloadGate, this.initialSnapshot, this.deviceInfoGate});
  final Completer<void>? downloadGate;
  final AndroidUpdateSnapshot? initialSnapshot;
  final Completer<AndroidUpdateDeviceInfo>? deviceInfoGate;
  final eventsController = StreamController<AndroidUpdateSnapshot>.broadcast();
  AndroidUpdateCandidate? lastCandidate;
  Map<String, String>? lastNotification;
  Object? installError;
  int downloadCalls = 0;
  int deviceInfoCalls = 0;
  int cancelCalls = 0;
  int permissionCalls = 0;
  bool _deviceInfoLoaded = false;
  bool eventsAccessedAfterDeviceInfo = false;

  @override
  Stream<AndroidUpdateSnapshot> get events {
    eventsAccessedAfterDeviceInfo = _deviceInfoLoaded;
    if (!_deviceInfoLoaded) throw StateError('device info must load first');
    return eventsController.stream;
  }

  @override
  Future<AndroidUpdateDeviceInfo> getDeviceInfo() async {
    deviceInfoCalls++;
    final info = deviceInfoGate == null
        ? _deviceInfo()
        : await deviceInfoGate!.future;
    _deviceInfoLoaded = true;
    return info;
  }

  @override
  Future<AndroidUpdateSnapshot> getState() async =>
      initialSnapshot ??
      const AndroidUpdateSnapshot(
        state: AndroidUpdateState.idle,
        receivedBytes: 0,
        totalBytes: 0,
      );
  @override
  Future<void> download(
    AndroidUpdateCandidate candidate, {
    required Map<String, String> notification,
  }) {
    downloadCalls++;
    lastCandidate = candidate;
    lastNotification = Map.of(notification);
    return downloadGate?.future ?? Future<void>.value();
  }

  @override
  Future<void> cancel() async => cancelCalls++;
  @override
  Future<bool> canInstall() async => true;
  @override
  Future<void> openInstallPermission() async => permissionCalls++;
  @override
  Future<void> install() async {
    if (installError != null) throw installError!;
  }
}

AndroidUpdateDeviceInfo _deviceInfo() => AndroidUpdateDeviceInfo(
  packageName: AndroidUpdateRepository.packageName,
  versionName: '1.0.0',
  versionCode: 10,
  sdkInt: 35,
  abis: const ['arm64-v8a'],
  signerSha256: [List.filled(64, 'a').join()],
);
