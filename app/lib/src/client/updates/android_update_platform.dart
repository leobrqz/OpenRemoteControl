import 'package:flutter/services.dart';

import 'android_update_models.dart';

/// Android operations owned by the native installer/download worker.
abstract interface class AndroidUpdatePlatform {
  Stream<AndroidUpdateSnapshot> get events;
  Future<AndroidUpdateDeviceInfo> getDeviceInfo();
  Future<AndroidUpdateSnapshot> getState();
  Future<void> download(
    AndroidUpdateCandidate candidate, {
    required Map<String, String> notification,
  });
  Future<void> cancel();
  Future<bool> canInstall();
  Future<void> openInstallPermission();
  Future<void> install();
}

class MethodChannelAndroidUpdatePlatform implements AndroidUpdatePlatform {
  MethodChannelAndroidUpdatePlatform({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _methodChannel =
           methodChannel ?? const MethodChannel('open_remote/updates'),
       _eventChannel =
           eventChannel ?? const EventChannel('open_remote/update_events');

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  Stream<AndroidUpdateSnapshot>? _events;

  @override
  Stream<AndroidUpdateSnapshot> get events => _events ??= _eventChannel
      .receiveBroadcastStream()
      .where((value) => value is Map)
      .map((value) => AndroidUpdateSnapshot.fromMap(value as Map));

  @override
  Future<AndroidUpdateDeviceInfo> getDeviceInfo() async {
    final value = await _methodChannel.invokeMapMethod<Object?, Object?>(
      'getDeviceInfo',
    );
    if (value == null) throw const AndroidUpdateException('unavailable');
    try {
      return AndroidUpdateDeviceInfo.fromMap(value);
    } on FormatException {
      throw const AndroidUpdateException('unavailable');
    }
  }

  @override
  Future<AndroidUpdateSnapshot> getState() async {
    final value = await _methodChannel.invokeMapMethod<Object?, Object?>(
      'getState',
    );
    if (value == null) throw const AndroidUpdateException('unavailable');
    try {
      return AndroidUpdateSnapshot.fromMap(value);
    } on FormatException {
      throw const AndroidUpdateException('unavailable');
    }
  }

  @override
  Future<void> download(
    AndroidUpdateCandidate candidate, {
    required Map<String, String> notification,
  }) async {
    await _methodChannel.invokeMethod<void>('download', {
      'candidate': candidate.toNativeMap(),
      'notification': notification,
    });
  }

  @override
  Future<void> cancel() => _methodChannel.invokeMethod<void>('cancel');

  @override
  Future<bool> canInstall() async =>
      await _methodChannel.invokeMethod<bool>('canInstall') ?? false;

  @override
  Future<void> openInstallPermission() =>
      _methodChannel.invokeMethod<void>('openInstallPermission');

  @override
  Future<void> install() => _methodChannel.invokeMethod<void>('install');
}
