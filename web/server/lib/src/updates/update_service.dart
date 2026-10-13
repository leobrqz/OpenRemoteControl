import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:open_remote_core/open_remote_core.dart';

import 'update_platform.dart';

class UpdateConflict implements Exception {
  const UpdateConflict(this.message);
  final String message;
  @override
  String toString() => message;
}

class UpdateService extends ChangeNotifier {
  UpdateService({required this.platform, required this.shutdown});

  final UpdatePlatform platform;
  final Future<void> Function() shutdown;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  String _state = 'idle';
  String? _currentVersion;
  Map<String, dynamic>? _candidate;
  String? _candidateId;
  Map<String, String>? _error;
  int? _progress;
  bool _managed = false;
  bool _initialized = false;
  bool _automaticCheckStarted = false;
  bool _disposed = false;

  String get state => _state;
  String? get trayVersion =>
      _state == 'available' ? (_candidate?['version'] as String?) : null;
  Map<String, Object?> get snapshot => {
    'state': _state,
    'currentVersion': _currentVersion,
    'availableVersion': _candidate?['version'],
    'candidateId': _candidateId,
    'releaseUrl': _candidate?['releaseUrl'],
    'notes': _candidate?['notes'],
    'progressPercent': _state == 'downloading' ? _progress : null,
    'error': _error,
  };

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      _subscription = platform.events.listen(
        (event) {
          if (event['type'] == 'progress' && _state == 'downloading') {
            final value = event['percent'];
            if (value is int) {
              _progress = value.clamp(0, 100);
              _notify();
            }
          }
        },
        onError: (Object error) {
          unawaited(
            DiagnosticLog.record(
              'WindowsUpdater',
              'Falha no canal de eventos.',
              error: error,
            ),
          );
        },
      );
      final context = await platform.getContext();
      _currentVersion = context['version'] as String?;
      _managed =
          context['managed'] == true &&
          context['packageId'] == 'org.openremotecontrol.windows' &&
          context['channel'] == 'win-x64';
      _setState(_managed ? 'idle' : 'disabled');
    } catch (error) {
      _managed = false;
      await _fail(error);
    }
  }

  Future<void> checkAfterStartup() async {
    if (_automaticCheckStarted) return;
    _automaticCheckStarted = true;
    await initialize();
    if (_managed) check();
  }

  void check() {
    _requireReady();
    _candidate = null;
    _candidateId = null;
    _setState('checking');
    unawaited(_check());
  }

  Future<void> _check() async {
    try {
      final candidate = await platform.check();
      if (candidate == null) {
        _setState('upToDate');
        return;
      }
      final version = candidate['version'];
      final url = candidate['releaseUrl'];
      if (version is! String ||
          !_newer(version, _currentVersion) ||
          candidate['packageId'] != 'org.openremotecontrol.windows' ||
          candidate['channel'] != 'win-x64' ||
          candidate['notes'] is! String ||
          url !=
              'https://github.com/leobrqz/OpenRemoteControl/releases/tag/v$version') {
        throw PlatformException(code: 'invalid_metadata');
      }
      _candidate = candidate;
      final random = Random.secure();
      _candidateId = List.generate(
        24,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      _setState('available');
    } catch (error) {
      await _fail(error);
    }
  }

  void defer(String id) {
    _requireCandidate(id);
    _setState('deferred');
  }

  void install(String id) {
    _requireCandidate(id);
    // Consent exists only in this operation; neither packages nor restart persist it.
    _progress = 0;
    _setState('downloading');
    unawaited(_install());
  }

  Future<void> _install() async {
    try {
      await platform.download();
      await platform.prepareApply();
      _setState('applying');
      // Let the initiating response / next dashboard poll observe the restart.
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      await shutdown().timeout(const Duration(seconds: 8));
    } catch (error) {
      await _fail(error);
    }
  }

  void _requireReady() {
    if (!_managed || ['checking', 'downloading', 'applying'].contains(_state)) {
      throw const UpdateConflict(
        'Atualizações indisponíveis ou operação em andamento.',
      );
    }
  }

  void _requireCandidate(String id) {
    if (!_managed || _state != 'available' || id != _candidateId) {
      throw const UpdateConflict(
        'Atualização expirada ou operação em andamento. Verifique novamente.',
      );
    }
  }

  void _setState(String state) {
    _state = state;
    _error = null;
    if (state != 'downloading') _progress = null;
    _notify();
  }

  Future<void> _fail(Object error) async {
    final code = error is PlatformException ? error.code : 'update_failed';
    const messages = {
      'timeout':
          'A atualização demorou demais. Verifique sua conexão e tente novamente.',
      'offline':
          'Não foi possível acessar o GitHub. Verifique sua conexão e tente novamente.',
      'rate_limited':
          'O GitHub limitou as solicitações. Aguarde alguns minutos e tente novamente.',
      'missing_asset':
          'A versão publicada está incompleta. Tente verificar novamente mais tarde.',
      'invalid_metadata':
          'Os dados da atualização são inválidos. Tente verificar novamente mais tarde.',
      'checksum':
          'O pacote está corrompido ou incompleto. Verifique novamente para baixar outra vez.',
      'insufficient_space': 'Libere espaço no disco antes de tentar novamente.',
      'unwritable_directory':
          'A pasta do aplicativo não permite gravação. Mova o pacote portátil para uma pasta do seu usuário.',
      'prepare_failed':
          'Não foi possível preparar a reinicialização. O servidor continua ativo; tente novamente.',
    };
    _candidateId = null;
    _state = 'failed';
    _progress = null;
    _error = {
      'code': code,
      'message':
          messages[code] ??
          'Não foi possível atualizar. Verifique o diagnóstico e tente novamente.',
    };
    _notify();
    await DiagnosticLog.record(
      'WindowsUpdater',
      'Operação recusada ($code).',
      error: error,
    );
  }

  static bool _newer(String version, String? current) {
    final pattern = RegExp(
      r'^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$',
    );
    if (!pattern.hasMatch(version) ||
        current == null ||
        !pattern.hasMatch(current)) {
      return false;
    }
    final next = version.split('.').map(int.parse).toList();
    final installed = current.split('.').map(int.parse).toList();
    for (var i = 0; i < 3; i++) {
      if (next[i] != installed[i]) return next[i] > installed[i];
    }
    return false;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
