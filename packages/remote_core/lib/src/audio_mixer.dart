import 'dart:convert';

const audioMixerFeature = 'audio.mixer';
const audioSessionLevelCommand = 'audio.session.level';
const audioSessionMuteCommand = 'audio.session.mute';
const maxAudioMixerSessions = 1024;
const maxAudioMixerLabelRunes = 80;

class AudioAppState {
  const AudioAppState({
    required this.id,
    required this.name,
    required this.device,
    required this.level,
    required this.muted,
    required this.systemSounds,
  });

  final String id, name, device;
  final int level;
  final bool muted, systemSounds;

  static AudioAppState? fromMap(Map<dynamic, dynamic> value) {
    final id = value['id'];
    final name = value['name'];
    final device = value['device'];
    final level = value['level'];
    final muted = value['muted'];
    final systemSounds = value['systemSounds'];
    if (id is! String ||
        !RegExp(r'^[1-9][0-9]{0,19}$').hasMatch(id) ||
        name is! String ||
        device is! String ||
        name.runes.length > maxAudioMixerLabelRunes ||
        device.runes.length > maxAudioMixerLabelRunes ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(name) ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(device) ||
        level is! int ||
        level < 0 ||
        level > 100 ||
        muted is! bool ||
        systemSounds is! bool) {
      return null;
    }
    return AudioAppState(
      id: id,
      name: name,
      device: device,
      level: level,
      muted: muted,
      systemSounds: systemSounds,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'device': device,
    'level': level,
    'muted': muted,
    'systemSounds': systemSounds,
  };

  @override
  bool operator ==(Object other) =>
      other is AudioAppState &&
      id == other.id &&
      name == other.name &&
      device == other.device &&
      level == other.level &&
      muted == other.muted &&
      systemSounds == other.systemSounds;

  @override
  int get hashCode => Object.hash(id, name, device, level, muted, systemSounds);
}

/// A null list means the mixer is temporarily unavailable, not empty.
class AudioMixerSnapshot {
  const AudioMixerSnapshot(this.sessions);
  final List<AudioAppState>? sessions;
}

/// Split snapshots into bounded secure messages without dropping applications.
List<Map<String, Object?>> audioMixerFrames(
  List<AudioAppState>? sessions,
  int revision,
) {
  if (sessions != null && sessions.length > maxAudioMixerSessions) {
    throw const FormatException('Too many audio sessions.');
  }
  final parts = <List<Map<String, Object?>>>[[]];
  for (final session in sessions ?? const <AudioAppState>[]) {
    if (AudioAppState.fromMap(session.toMap()) == null) {
      throw const FormatException('Invalid audio session.');
    }
    final item = session.toMap();
    final candidate = [...parts.last, item];
    // Ciphertext is base64 encoded and binary wire fields are capped at 4096
    // characters; leave room for metadata as well as the base64 expansion.
    if (utf8.encode(jsonEncode(candidate)).length > 2700) {
      if (parts.last.isEmpty) {
        throw const FormatException('Audio session too large.');
      }
      parts.add([item]);
    } else {
      parts.last.add(item);
    }
  }
  return [
    for (var index = 0; index < parts.length; index++)
      {
        'kind': audioMixerFeature,
        'revision': revision,
        'index': index,
        'parts': parts.length,
        'available': sessions != null,
        'sessions': parts[index],
      },
  ];
}

/// Applies complete snapshots only, so a partial transfer never replaces the UI.
class AudioMixerAssembler {
  int _lastRevision = -1;
  int? _revision, _partCount;
  int _nextIndex = 0;
  final _sessions = <AudioAppState>[];
  final _ids = <String>{};

  AudioMixerSnapshot? add(Map<String, dynamic> message) {
    final revision = message['revision'];
    final index = message['index'];
    final parts = message['parts'];
    final available = message['available'];
    final raw = message['sessions'];
    if (message['kind'] != audioMixerFeature ||
        revision is! int ||
        revision < 0 ||
        revision <= _lastRevision ||
        index is! int ||
        parts is! int ||
        parts < 1 ||
        parts > maxAudioMixerSessions ||
        index < 0 ||
        index >= parts ||
        available is! bool ||
        raw is! List ||
        (!available && (index != 0 || parts != 1 || raw.isNotEmpty))) {
      _reset();
      return null;
    }
    if (index == 0) {
      _reset();
      _revision = revision;
      _partCount = parts;
    }
    if (_revision != revision ||
        _partCount != parts ||
        _nextIndex != index ||
        _sessions.length + raw.length > maxAudioMixerSessions) {
      _reset();
      return null;
    }
    for (final entry in raw) {
      final state = entry is Map ? AudioAppState.fromMap(entry) : null;
      if (state == null || !_ids.add(state.id)) {
        _reset();
        return null;
      }
      _sessions.add(state);
    }
    _nextIndex++;
    if (_nextIndex != parts) return null;
    final result = AudioMixerSnapshot(
      available ? List<AudioAppState>.unmodifiable(_sessions) : null,
    );
    _lastRevision = revision;
    _reset();
    return result;
  }

  void _reset() {
    _revision = _partCount = null;
    _nextIndex = 0;
    _sessions.clear();
    _ids.clear();
  }
}
