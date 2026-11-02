import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_remote_core/open_remote_core.dart';
import 'package:open_remote_server/src/host/state_publisher.dart';

void main() {
  testWidgets('publishes mixer snapshots only when their contents change', (
    tester,
  ) async {
    var current = [
      const AudioAppState(
        id: '1',
        name: 'Player',
        device: 'Speakers',
        level: 20,
        muted: false,
        systemSounds: false,
      ),
    ];
    final sent = <List<AudioAppState>?>[];
    final publisher = StatePublisher<List<AudioAppState>>(
      read: () async => List.of(current),
      send: (state) async => sent.add(state),
      equals: listEquals,
      onReadError: (error, _) => fail('$error'),
      onSendError: (error, _) => fail('$error'),
    )..start();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(sent.length, 1);
    current = [
      const AudioAppState(
        id: '1',
        name: 'Player',
        device: 'Speakers',
        level: 21,
        muted: true,
        systemSounds: false,
      ),
    ];
    await tester.pump(const Duration(milliseconds: 500));
    expect(sent.length, 2);
    expect(sent.last!.single.level, 21);
    expect(sent.last!.single.muted, isTrue);
    publisher.stop();
  });

  testWidgets('publishes changes, mute, device loss and recovery', (
    tester,
  ) async {
    VolumeState? current = const VolumeState(level: 37, muted: false);
    final sent = <VolumeState?>[];
    final errors = <Object>[];
    final publisher = StatePublisher<VolumeState>(
      read: () async => current,
      send: (state) async => sent.add(state),
      onReadError: (error, _) => errors.add(error),
      onSendError: (error, _) => errors.add(error),
    )..start();

    await tester.pump();
    expect(sent, [current]);
    await tester.pump(const Duration(seconds: 1));
    expect(sent.length, 1);

    current = const VolumeState(level: 42, muted: false);
    await tester.pump(const Duration(milliseconds: 500));
    current = const VolumeState(level: 42, muted: true);
    await tester.pump(const Duration(milliseconds: 500));
    current = null;
    await tester.pump(const Duration(milliseconds: 500));
    current = const VolumeState(level: 13, muted: false);
    await tester.pump(const Duration(milliseconds: 500));
    expect(sent, [
      const VolumeState(level: 37, muted: false),
      const VolumeState(level: 42, muted: false),
      const VolumeState(level: 42, muted: true),
      null,
      const VolumeState(level: 13, muted: false),
    ]);
    expect(errors, isEmpty);
    publisher.stop();
    await tester.pump(const Duration(seconds: 1));
    expect(sent.length, 5);
  });

  testWidgets('reports a read failure once, clears stale volume and retries', (
    tester,
  ) async {
    var failed = false;
    final sent = <VolumeState?>[];
    final errors = <Object>[];
    final publisher = StatePublisher<VolumeState>(
      read: () async {
        if (failed) throw StateError('audio offline');
        return const VolumeState(level: 50, muted: false);
      },
      send: (state) async => sent.add(state),
      onReadError: (error, _) => errors.add(error),
      onSendError: (error, _) => errors.add(error),
    )..start();
    await tester.pump();
    failed = true;
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(sent, [const VolumeState(level: 50, muted: false), null]);
    expect(errors.length, 1);
    failed = false;
    await tester.pump(const Duration(milliseconds: 500));
    expect(sent.last, const VolumeState(level: 50, muted: false));
    failed = true;
    await tester.pump(const Duration(milliseconds: 500));
    expect(errors.length, 2);
    publisher.stop();
  });

  testWidgets('does not overlap updates or send after the session stops', (
    tester,
  ) async {
    final read = Completer<VolumeState?>();
    var reads = 0;
    final sent = <VolumeState?>[];
    final publisher = StatePublisher<VolumeState>(
      read: () {
        reads++;
        return read.future;
      },
      send: (state) async => sent.add(state),
      onReadError: (error, _) => fail('$error'),
      onSendError: (error, _) => fail('$error'),
    )..start();
    await tester.pump(const Duration(seconds: 2));
    expect(reads, 1);
    publisher.stop();
    read.complete(const VolumeState(level: 1, muted: false));
    await tester.pump();
    expect(sent, isEmpty);
  });
}
