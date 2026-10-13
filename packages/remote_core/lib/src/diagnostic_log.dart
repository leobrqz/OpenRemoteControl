import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;

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
    developer.log(
      line,
      name: 'OpenRemote',
      error: error,
      stackTrace: stackTrace,
    );

    _writeQueue = _writeQueue.then((_) async {
      try {
        final file = await _logFile();
        await file.parent.create(recursive: true);
        final stack = stackTrace == null ? '' : '\n$stackTrace';
        await file.writeAsString('$line$stack\n', mode: FileMode.append);
      } catch (writeError) {
        developer.log(
          '[OpenRemote][logs] Não foi possível salvar o log: $writeError',
        );
      }
    });
    await _writeQueue;
  }

  static Future<String> export() async {
    await _writeQueue;
    final path = await _resolveLogPath();
    // Native startup and updater recovery also append to this file.
    String? persisted;
    try {
      final file = File(path);
      if (await file.exists()) {
        final handle = await file.open();
        try {
          final size = await handle.length();
          await handle.setPosition(size > 256 * 1024 ? size - 256 * 1024 : 0);
          persisted = utf8.decode(
            await handle.read(256 * 1024),
            allowMalformed: true,
          );
        } finally {
          await handle.close();
        }
      }
    } catch (_) {}
    return [
      'Open Remote Control — diagnóstico',
      'Plataforma: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      'Arquivo: $path',
      '',
      if (persisted != null) persisted else ..._entries,
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
