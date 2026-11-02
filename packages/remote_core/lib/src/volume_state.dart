/// Optional capability for receiving the default output device's volume.
const volumeStateFeature = 'volume.state';

class VolumeState {
  const VolumeState({required this.level, required this.muted});

  final int level;
  final bool muted;

  /// Parses an untrusted platform or protocol payload.
  static VolumeState? fromMap(Map<dynamic, dynamic> payload) {
    final level = payload['level'];
    final muted = payload['muted'];
    if (level is! int || level < 0 || level > 100 || muted is! bool) {
      return null;
    }
    return VolumeState(level: level, muted: muted);
  }

  Map<String, Object?> toMessage() => {
    'kind': volumeStateFeature,
    'level': level,
    'muted': muted,
  };

  @override
  bool operator ==(Object other) =>
      other is VolumeState && level == other.level && muted == other.muted;

  @override
  int get hashCode => Object.hash(level, muted);
}
