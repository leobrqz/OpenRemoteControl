import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

class DiagnosticLog {
  DiagnosticLog._();

  static const int _maxEntries = 300;
  static final List<String> _entries = [];
  static Future<void> _writeQueue = Future<void>.value();
  static String? _path;

  static String? get filePath => _path;

  static Future<void> record(
    String component,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) async {
    final now = DateTime.now().toIso8601String();
    final details = error == null ? '' : ' | $error';
    final line = '[$now] [$component] $message$details';
    _entries.add(line);
    if (_entries.length > _maxEntries) {
      _entries.removeRange(0, _entries.length - _maxEntries);
    }
    if (stackTrace != null) _entries.add(stackTrace.toString());
    debugPrint(line);
    if (stackTrace != null) debugPrint(stackTrace.toString());

    _writeQueue = _writeQueue.then((_) async {
      try {
        final file = await _logFile();
        await file.parent.create(recursive: true);
        final stack = stackTrace == null ? '' : '\n$stackTrace';
        await file.writeAsString('$line$stack\n', mode: FileMode.append);
      } catch (writeError) {
        debugPrint(
          '[OpenRemote][logs] Não foi possível salvar o log: $writeError',
        );
      }
    });
    await _writeQueue;
  }

  static Future<String> export() async {
    await _writeQueue;
    final path = await _resolveLogPath();
    return [
      'Open Remote Control — diagnóstico',
      'Plataforma: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      'Arquivo: $path',
      '',
      ..._entries,
    ].join('\n');
  }

  static Future<File> _logFile() async {
    final path = await _resolveLogPath();
    _path = path;
    return File(path);
  }

  static Future<String> _resolveLogPath() async {
    if (Platform.isWindows) {
      final appData = Platform.environment['LOCALAPPDATA'];
      if (appData != null && appData.isNotEmpty) {
        return '$appData${Platform.pathSeparator}OpenRemoteControl'
            '${Platform.pathSeparator}logs${Platform.pathSeparator}open-remote.log';
      }
    }
    final temp = Directory.systemTemp.path;
    return '$temp${Platform.pathSeparator}open-remote-control.log';
  }
}
