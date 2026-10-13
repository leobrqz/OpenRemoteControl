import 'package:flutter/services.dart';

abstract class UpdatePlatform {
  Stream<Map<String, dynamic>> get events;
  Future<Map<String, dynamic>> getContext();
  Future<Map<String, dynamic>?> check();
  Future<void> download();
  Future<void> prepareApply();
}

class NativeUpdatePlatform implements UpdatePlatform {
  static const _methods = MethodChannel('open_remote/updater');
  static const _events = EventChannel('open_remote/updater_events');

  @override
  Stream<Map<String, dynamic>> get events => _events
      .receiveBroadcastStream()
      .map((event) => Map<String, dynamic>.from(event as Map));
  @override
  Future<Map<String, dynamic>> getContext() async => Map<String, dynamic>.from(
    (await _methods.invokeMapMethod('getContext'))!,
  );
  @override
  Future<Map<String, dynamic>?> check() async {
    final candidate = await _methods.invokeMapMethod('check');
    return candidate == null ? null : Map<String, dynamic>.from(candidate);
  }

  @override
  Future<void> download() => _methods.invokeMethod<void>('download');
  @override
  Future<void> prepareApply() => _methods.invokeMethod<void>('prepareApply');
}
