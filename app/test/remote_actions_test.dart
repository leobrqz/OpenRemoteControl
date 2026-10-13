import 'package:flutter_test/flutter_test.dart';
import 'package:open_remote_control/src/client/controls/remote_actions.dart';
import 'package:open_remote_control/src/client/preferences/client_preferences.dart';

void main() {
  test(
    'swap buttons, invert and scale scrolling, and release the original held button',
    () {
      final commands = <Map<String, Object?>>[];
      var p = const ClientPreferences(
        swapButtons: true,
        invertScroll: true,
        scrollSensitivity: 2,
      );
      var vibrations = 0;
      final actions = RemoteActions(
        send: (command) async => commands.add(command),
        preferences: () => p,
        connected: () => true,
        vibrate: () => vibrations++,
      );
      actions.click('left');
      actions.scroll(120);
      final held = actions.holdPrimary();
      p = p.copyWith(swapButtons: false);
      actions.releaseButton(held);
      expect(commands.map((c) => c['kind']), [
        'mouse.button',
        'mouse.button',
        'mouse.scroll',
        'mouse.button',
        'mouse.button',
      ]);
      expect(commands[0]['button'], 'right');
      expect(commands[2]['delta'], -240);
      expect(commands[4]['button'], 'right');
      expect(commands[4]['pressed'], false);
      expect(vibrations, 2);
      actions.dispose();
    },
  );

  testWidgets(
    'motion is coalesced, bounded and preserves fractional movement',
    (tester) async {
      final commands = <Map<String, Object?>>[];
      final actions = RemoteActions(
        send: (command) async => commands.add(command),
        preferences: () =>
            const ClientPreferences(pointerSensitivity: 1, mouseUpdateRate: 30),
        connected: () => true,
        vibrate: () {},
      );
      actions.move(0.4, 0.4);
      actions.move(0.4, 0.4);
      actions.move(0.4, 0.4);
      expect(commands, isEmpty);
      await tester.pump(const Duration(milliseconds: 34));
      expect(commands.single['dx'], 1.0);
      actions.move(0.8, 0.8);
      actions.flushMotion();
      expect(commands.last['dx'], 1.0);
      commands.clear();
      actions.move(1100, -1200);
      actions.flushMotion();
      expect(commands.length, 3);
      expect(
        commands.every(
          (c) =>
              (c['dx'] as double).abs() <= 500 &&
              (c['dy'] as double).abs() <= 500,
        ),
        true,
      );
      expect(
        commands.fold<double>(0, (sum, c) => sum + (c['dx'] as double)),
        1100,
      );
      actions.dispose();
    },
  );

  test('offline gestures are discarded and Unicode text is chunked safely', () {
    final commands = <Map<String, Object?>>[];
    var connected = false;
    final actions = RemoteActions(
      send: (command) async => commands.add(command),
      preferences: () => const ClientPreferences(hapticFeedback: false),
      connected: () => connected,
    );
    actions.move(100, 100);
    actions.click('left');
    actions.scroll(100);
    actions.media('playPause');
    expect(commands, isEmpty);
    connected = true;
    actions.flushMotion();
    expect(commands, isEmpty);
    final text = List.filled(400, 'a💚').join();
    actions.text(text);
    expect(commands.map((c) => c['text']).join(), text);
    expect(commands.every((c) => (c['text'] as String).length <= 512), true);
    actions.dispose();
  });

  test(
    'navigation releases held keys and flushes movement before button release',
    () {
      final commands = <Map<String, Object?>>[];
      final actions = RemoteActions(
        send: (command) async => commands.add(command),
        preferences: () => const ClientPreferences(
          pointerSensitivity: 1,
          hapticFeedback: false,
        ),
        connected: () => true,
      );
      actions.holdPrimary();
      actions.modifier('control', true);
      actions.move(20, 30);
      actions.releaseAll();
      expect(commands.map((c) => c['kind']), [
        'mouse.button',
        'keyboard.modifier',
        'mouse.move',
        'mouse.button',
        'keyboard.modifier',
      ]);
      expect(commands[3]['pressed'], false);
      expect(commands[4]['pressed'], false);
      actions.dispose();
    },
  );
}
