import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_remote_control/main.dart';
import 'package:open_remote_control/src/client/client_screen.dart';
import 'package:open_remote_control/src/client/client_service.dart';
import 'package:open_remote_control/src/client/controls/media_control.dart';
import 'package:open_remote_control/src/client/controls/mouse_control.dart';
import 'package:open_remote_control/src/client/preferences/client_preferences.dart';
import 'package:open_remote_core/open_remote_core.dart';

const _host = SavedHost(
  serverId: 'test-pc',
  name: 'Test PC',
  addresses: ['192.168.1.2'],
  port: 47652,
  signingPublicKey: 'test-key',
);

class _FakeService extends RemoteClientService {
  bool connected = false, session = false;
  int reconnects = 0;
  final commands = <Map<String, Object?>>[];
  @override
  bool get isConnected => connected;
  @override
  bool get hasSession => session;
  @override
  SavedHost? get currentHost => session ? _host : null;
  @override
  String? get connectedAddress => session ? '192.168.1.2' : null;
  @override
  Future<List<SavedHost>> loadSavedHosts() async => [_host];
  @override
  Future<List<DiscoveredHost>> discoverHosts() async => [];
  @override
  Future<void> updateDiscoveredAddresses() async {}
  @override
  Future<void> connectSaved(SavedHost host) async {
    connected = session = true;
    notifyListeners();
  }

  @override
  Future<void> reconnect() async {
    reconnects++;
    connected = true;
    notifyListeners();
  }

  @override
  Future<void> disconnect({bool clearSession = true}) async {
    connected = false;
    if (clearSession) session = false;
    notifyListeners();
  }

  @override
  Future<void> send(Map<String, Object?> command) async {
    commands.add(command);
  }

  void drop() {
    connected = false;
    notifyListeners();
  }
}

void androidTest(
  String description,
  Future<void> Function(WidgetTester) body,
) => testWidgets(
  description,
  body,
  variant: TargetPlatformVariant.only(TargetPlatform.android),
);

void main() {
  final platformCalls = <MethodCall>[];
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    platformCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('open_remote/preferences'),
          (call) async {
            platformCalls.add(call);
            return call.method == 'requestNotificationPermission' ? true : null;
          },
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('open_remote/preferences'),
          null,
        );
  });

  Future<PreferencesController> preferences() async {
    final p = PreferencesController();
    await p.update(
      p.value.copyWith(
        automaticDiscovery: false,
        updateServerAddress: false,
        hapticFeedback: false,
      ),
    );
    return p;
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Configurações'));
    await tester.pumpAndSettle();
  }

  androidTest(
    'home has no marketing hero or pills, drawer opens real settings',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final p = await preferences();
      await tester.pumpWidget(OpenRemoteApp(preferences: p));
      await tester.pumpAndSettle();
      expect(find.text('Computadores'), findsOneWidget);
      expect(find.text('ANDROID'), findsNothing);
      expect(find.text('SEM BLUETOOTH'), findsNothing);
      expect(find.textContaining('Controle seu PC'), findsNothing);
      await openSettings(tester);
      await tester.tap(find.text('Mouse'));
      await tester.pumpAndSettle();
      expect(find.text('Multi-touch'), findsOneWidget);
      await tester.tap(find.text('Inverter rolagem'));
      await tester.pumpAndSettle();
      expect(p.value.invertScroll, true);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aparência e controles'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tema'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Claro'));
      await tester.pumpAndSettle();
      expect(p.value.themeMode, ThemeMode.light);
      expect(
        Theme.of(tester.element(find.text('Tema'))).brightness,
        Brightness.light,
      );
      final restored = PreferencesController();
      await restored.load();
      expect(restored.value.invertScroll, true);
      expect(restored.value.themeMode, ThemeMode.light);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      p.dispose();
      restored.dispose();
    },
  );

  androidTest(
    'control navigation and automatic reconnect retain the remote screen',
    (tester) async {
      final p = await preferences();
      final service = _FakeService();
      await tester.pumpWidget(
        MaterialApp(
          home: ClientScreen(preferences: p, service: service),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test PC'));
      await tester.pumpAndSettle();
      expect(find.byType(MouseControl), findsOneWidget);
      await tester.tap(find.text('Mídia'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Pausar / tocar'));
      await tester.pump();
      expect(service.commands.last, {
        'kind': 'media.command',
        'action': 'playPause',
      });
      service.drop();
      await tester.pump();
      expect(find.byType(MediaControl), findsOneWidget);
      expect(find.text('Reconectar'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(service.reconnects, 1);
      expect(service.connected, true);
      expect(find.byType(MediaControl), findsOneWidget);
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Configurações'));
      await tester.pumpAndSettle();
      expect(service.connected, true);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      p.dispose();
    },
  );

  androidTest(
    'disabling automatic reconnect and background service is effective',
    (tester) async {
      final p = await preferences();
      await p.update(
        p.value.copyWith(
          autoReconnect: false,
          keepConnectionInBackground: true,
        ),
      );
      final service = _FakeService()
        ..connected = true
        ..session = true;
      await tester.pumpWidget(
        MaterialApp(
          home: ClientScreen(preferences: p, service: service),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        platformCalls.any(
          (call) =>
              call.method == 'setBackgroundConnection' &&
              call.arguments['enabled'] == true,
        ),
        true,
      );
      await p.update(p.value.copyWith(keepConnectionInBackground: false));
      await tester.pumpAndSettle();
      expect(
        platformCalls
            .lastWhere((call) => call.method == 'setBackgroundConnection')
            .arguments['enabled'],
        false,
      );
      service.drop();
      await tester.pump(const Duration(seconds: 31));
      expect(service.reconnects, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      p.dispose();
    },
  );

  androidTest('mouse layout supports a short display and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final p = await preferences();
    final service = _FakeService();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.5)),
          child: child!,
        ),
        home: ClientScreen(preferences: p, service: service),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test PC'));
    await tester.pumpAndSettle();
    expect(find.byType(MouseControl), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    p.dispose();
  });

  androidTest(
    'backgrounding releases keyboard modifiers and reconnect-off stops the service after loss',
    (tester) async {
      final p = await preferences();
      await p.update(
        p.value.copyWith(
          defaultControl: ControlPage.keyboard,
          keepConnectionInBackground: true,
          autoReconnect: false,
        ),
      );
      final service = _FakeService();
      await tester.pumpWidget(
        MaterialApp(
          home: ClientScreen(preferences: p, service: service),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test PC'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ctrl'));
      await tester.pump();
      expect(service.commands.last['pressed'], true);
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
        await tester.pump();
      }
      expect(service.commands.last, {
        'kind': 'keyboard.modifier',
        'key': 'control',
        'pressed': false,
      });
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
        await tester.pump();
      }
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Ctrl'))
            .selected,
        false,
      );
      service.drop();
      await tester.pumpAndSettle();
      expect(
        platformCalls
            .lastWhere((call) => call.method == 'setBackgroundConnection')
            .arguments['enabled'],
        false,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      p.dispose();
    },
  );
}
