import 'package:open_remote_core/open_remote_core.dart';
import 'package:test/test.dart';

void main() {
  test('serializes and validates output volume states', () {
    const state = VolumeState(level: 63, muted: true);
    expect(state.toMessage(), {
      'kind': volumeStateFeature,
      'level': 63,
      'muted': true,
    });
    expect(VolumeState.fromMap(state.toMessage()), state);
    expect(
      VolumeState.fromMap({'level': 0, 'muted': false}),
      const VolumeState(level: 0, muted: false),
    );
    expect(
      VolumeState.fromMap({'level': 100, 'muted': true}),
      const VolumeState(level: 100, muted: true),
    );

    for (final payload in [
      {'level': -1, 'muted': false},
      {'level': 101, 'muted': false},
      {'level': 12.0, 'muted': false},
      {'level': '12', 'muted': false},
      {'level': 12, 'muted': null},
      {'level': null, 'muted': null},
      <String, Object?>{},
    ]) {
      expect(VolumeState.fromMap(payload), isNull, reason: '$payload');
    }
  });
}
