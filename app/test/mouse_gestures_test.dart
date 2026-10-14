import 'package:flutter/material.dart';
import 'package:open_remote_control/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_remote_control/src/client/controls/mouse_control.dart';
import 'package:open_remote_control/src/client/controls/remote_actions.dart';
import 'package:open_remote_control/src/client/preferences/client_preferences.dart';

void main() {
  final commands = <Map<String, Object?>>[];
  late RemoteActions actions;
  var prefs = const ClientPreferences();
  Future<void> setup(WidgetTester tester, {bool dragMode = false}) async {
    commands.clear();
    actions = RemoteActions(
      send: (c) async => commands.add(c),
      preferences: () => prefs,
      connected: () => true,
      vibrate: () {},
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt', 'BR'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 260,
              child: MouseTouchpad(
                actions: actions,
                preferences: prefs,
                active: true,
                dragMode: dragMode,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('one finger moves and taps, two fingers tap secondary button', (
    tester,
  ) async {
    prefs = const ClientPreferences(
      pointerSensitivity: 1,
      limitMouseUpdates: false,
    );
    await setup(tester);
    final center = tester.getCenter(find.byType(MouseTouchpad));
    final one = await tester.startGesture(center, pointer: 1);
    await one.moveBy(const Offset(20, 10));
    await one.up();
    expect(commands.single, {'kind': 'mouse.move', 'dx': 20.0, 'dy': 10.0});
    commands.clear();
    await tester.tapAt(center);
    expect(commands.map((c) => c['pressed']), [true, false]);
    commands.clear();
    final a = await tester.startGesture(
      center - const Offset(30, 0),
      pointer: 2,
    );
    final b = await tester.startGesture(
      center + const Offset(30, 0),
      pointer: 3,
    );
    await a.up();
    await b.up();
    expect(commands.map((c) => c['button']), ['right', 'right']);
    await tester.pumpWidget(const SizedBox.shrink());
    actions.dispose();
  });

  testWidgets('two finger scroll and pinch stay separate from pointer motion', (
    tester,
  ) async {
    prefs = const ClientPreferences(
      pointerSensitivity: 1,
      limitMouseUpdates: false,
    );
    await setup(tester);
    final center = tester.getCenter(find.byType(MouseTouchpad));
    final a = await tester.startGesture(
      center - const Offset(50, 0),
      pointer: 1,
    );
    final b = await tester.startGesture(
      center + const Offset(50, 0),
      pointer: 2,
    );
    await a.moveBy(const Offset(0, -20));
    await b.moveBy(const Offset(0, -20));
    await a.up();
    await b.moveBy(const Offset(10, 0));
    await b.up();
    expect(commands, isNotEmpty);
    expect(commands.every((c) => c['kind'] == 'mouse.scroll'), true);
    commands.clear();
    final c = await tester.startGesture(
      center - const Offset(50, 0),
      pointer: 3,
    );
    final d = await tester.startGesture(
      center + const Offset(50, 0),
      pointer: 4,
    );
    await c.moveBy(const Offset(-30, 0));
    await d.moveBy(const Offset(30, 0));
    await c.up();
    await d.up();
    expect(commands, isNotEmpty);
    expect(commands.every((c) => c['kind'] == 'mouse.zoom'), true);
    await tester.pumpWidget(const SizedBox.shrink());
    actions.dispose();
  });

  testWidgets('cancel and unmount release drag without a trailing click', (
    tester,
  ) async {
    prefs = const ClientPreferences(pointerSensitivity: 1);
    await setup(tester, dragMode: true);
    final drag = await tester.startGesture(
      tester.getCenter(find.byType(MouseTouchpad)),
    );
    await drag.moveBy(const Offset(20, 10));
    await drag.cancel();
    expect(commands.first['pressed'], true);
    expect(commands.last['pressed'], false);
    expect(commands.where((c) => c['kind'] == 'mouse.button').length, 2);
    commands.clear();
    await tester.startGesture(
      tester.getCenter(find.byType(MouseTouchpad)),
      pointer: 5,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    expect(commands.map((c) => c['pressed']), [true, false]);
    actions.dispose();
  });

  testWidgets('double tap hold drags and disabled multitouch sends no scroll', (
    tester,
  ) async {
    prefs = const ClientPreferences(doubleTapDrag: true, pointerSensitivity: 1);
    await setup(tester);
    final center = tester.getCenter(find.byType(MouseTouchpad));
    await tester.tapAt(center);
    final second = await tester.startGesture(center, pointer: 2);
    await second.moveBy(const Offset(20, 10));
    await second.up();
    expect(
      commands
          .where((c) => c['kind'] == 'mouse.button')
          .map((c) => c['pressed']),
      [true, false, true, false],
    );
    await tester.pumpWidget(const SizedBox.shrink());
    actions.dispose();
    prefs = const ClientPreferences(multiTouch: false);
    await setup(tester);
    final a = await tester.startGesture(
      center - const Offset(30, 0),
      pointer: 3,
    );
    final b = await tester.startGesture(
      center + const Offset(30, 0),
      pointer: 4,
    );
    await a.moveBy(const Offset(0, -30));
    await b.moveBy(const Offset(0, -30));
    await a.up();
    await b.up();
    expect(commands, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    actions.dispose();
  });
}
