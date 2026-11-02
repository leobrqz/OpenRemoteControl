import 'dart:async';

import 'package:flutter/services.dart';
import 'package:open_remote_core/open_remote_core.dart';

import '../platform/windows_input.dart';

class AudioMixerCommands {
  AudioMixerCommands._();

  static Future<void> apply(Map<String, dynamic> command) async {
    final kind = command['kind'];
    final id = command['id'];
    if (id is! String || !RegExp(r'^[1-9][0-9]{0,19}$').hasMatch(id)) {
      throw const FormatException('Invalid audio session.');
    }
    final level = command['level'];
    final muted = command['muted'];
    if (kind == audioSessionLevelCommand) {
      if (level is! int || level < 0 || level > 100) {
        throw const FormatException('Invalid audio session volume.');
      }
    } else if (kind == audioSessionMuteCommand) {
      if (muted is! bool) {
        throw const FormatException('Invalid audio session mute state.');
      }
    } else {
      throw const FormatException('Invalid audio session command.');
    }
    try {
      if (kind == audioSessionLevelCommand) {
        await WindowsInput.setAudioSessionLevel(id, level as int);
      } else {
        await WindowsInput.setAudioSessionMute(id, muted as bool);
      }
    } on PlatformException catch (error, stackTrace) {
      // A device can disappear between a snapshot and a command.
      unawaited(
        DiagnosticLog.record(
          'Windows',
          'Could not update the audio session.',
          error: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}
