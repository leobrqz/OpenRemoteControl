import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:open_remote_control/l10n/app_localizations.dart';
import 'package:open_remote_control/src/client/about_service.dart';
import 'package:open_remote_control/src/client/client_screen.dart';
import 'package:open_remote_control/src/client/client_service.dart';
import 'package:open_remote_control/src/client/controls/keyboard_control.dart';
import 'package:open_remote_control/src/client/controls/media_control.dart';
import 'package:open_remote_control/src/client/controls/mouse_control.dart';
import 'package:open_remote_control/src/client/manual_connection_dialog.dart';
import 'package:open_remote_control/src/client/pairing_scanner_screen.dart';
import 'package:open_remote_control/src/client/preferences/client_preferences.dart';
import 'package:open_remote_control/src/client/preferences/settings_page.dart';

const _host = SavedHost(
  serverId: 'localization-pc',
  name: 'Meu PC',
  addresses: ['192.168.1.42'],
  port: 47652,
  signingPublicKey: 'unchanged-key',
);

class _ConnectedService extends RemoteClientService {
  final commands = <Map<String, Object?>>[];
  int disconnects = 0;
  @override
  bool get isConnected => true;
  @override
  bool get hasSession => true;
  @override
  SavedHost get currentHost => _host;
  @override
  String get connectedAddress => _host.addresses.first;
  @override
  Future<List<SavedHost>> loadSavedHosts() async => [_host];
  @override
  Future<void> send(Map<String, Object?> command) async =>
      commands.add(command);
  @override
  Future<void> disconnect({bool clearSession = true}) async => disconnects++;
}

class _About extends AboutService {
  @override
  Future<String> installedVersion() async => '0.4.1+11';
}

Widget _localized(
  PreferencesController preferences,
  Widget child, {
  double textScale = 1,
}) => ListenableBuilder(
  listenable: preferences,
  builder: (context, _) => MaterialApp(
    locale: preferences.value.locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: const [Locale('en', 'US'), Locale('pt', 'BR')],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: child,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final platformCalls = <MethodCall>[];
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    platformCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('open_remote/preferences'),
          (call) async {
            platformCalls.add(call);
            if (call.method == 'setLanguage') {
              return call.arguments['language'] as String;
            }
            return call.method == 'requestNotificationPermission' ? true : null;
          },
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('open_remote/preferences'),
          null,
        );
  });

  Future<PreferencesController> preferences() async {
    final value = PreferencesController();
    await value.update(
      value.value.copyWith(
        automaticDiscovery: false,
        updateServerAddress: false,
        hapticFeedback: false,
      ),
    );
    addTearDown(value.dispose);
    return value;
  }

  Future<void> drawer(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'US English default ignores a Portuguese system locale',
    (tester) async {
      tester.binding.platformDispatcher.localesTestValue = [
        const Locale('pt', 'BR'),
      ];
      addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
      final p = await preferences();
      final service = _ConnectedService();
      addTearDown(service.dispose);
      await tester.pumpWidget(
        _localized(p, ClientScreen(preferences: p, service: service)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Computers'), findsOneWidget);
      expect(p.value.locale, const Locale('en', 'US'));
      await drawer(tester);
      final about = tester.getRect(find.widgetWithText(ListTile, 'About'));
      final selector = tester.getRect(find.byType(DropdownButton<String>));
      expect(selector.top, greaterThanOrEqualTo(about.bottom));
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Português (Brasil)').last);
      await tester.pumpAndSettle();
      expect(p.value.language, 'pt-BR');
      expect(find.text('Sobre'), findsOneWidget);
      expect(find.text('Computadores'), findsWidgets);
      expect(service.disconnects, 0);
      final restored = PreferencesController();
      await restored.load();
      expect(restored.value.language, 'pt-BR');
      restored.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'switching keeps keyboard text, modifiers and an active session',
    (tester) async {
      final p = await preferences();
      final service = _ConnectedService();
      addTearDown(service.dispose);
      await tester.pumpWidget(
        _localized(p, ClientScreen(preferences: p, service: service)),
      );
      await tester.pumpAndSettle();
      await drawer(tester);
      await tester.tap(find.text('Keyboard'));
      await tester.pumpAndSettle();
      expect(find.byType(KeyboardControl), findsOneWidget);
      await tester.enterText(
        find.byType(TextField),
        'Texto do usuário 1.234,56',
      );
      await tester.tap(find.widgetWithText(FilterChip, 'Ctrl'));
      await tester.pump();
      final commandCount = service.commands.length;
      await p.update(p.value.copyWith(language: 'pt-BR'));
      await tester.pumpAndSettle();
      expect(find.text('Enviar texto'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Texto do usuário 1.234,56',
      );
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Ctrl'))
            .selected,
        true,
      );
      expect(service.commands.length, commandCount);
      expect(service.disconnects, 0);
      expect(service.currentHost, same(_host));
      expect(
        platformCalls
            .where((call) => call.method == 'setLanguage')
            .last
            .arguments['language'],
        'pt-BR',
      );
      await p.update(p.value.copyWith(language: 'en-US'));
      await tester.pumpAndSettle();
      expect(find.text('Send text'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Texto do usuário 1.234,56',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'manual pairing preserves input and translates visible validation',
    (tester) async {
      final p = await preferences();
      await tester.pumpWidget(
        _localized(
          p,
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<ManualEndpoint>(
                  context: context,
                  builder: (_) => const ManualConnectionDialog(),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '192.168.1.42');
      await tester.enterText(find.byType(TextFormField).last, '12');
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();
      await p.update(p.value.copyWith(language: 'pt-BR'));
      await tester.pumpAndSettle();
      expect(find.text('Conectar por IP'), findsOneWidget);
      expect(find.text('Use uma porta de 1024 a 65535.'), findsOneWidget);
      final fields = tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .toList();
      expect(fields.first.controller!.text, '192.168.1.42');
      expect(fields.last.controller!.text, '12');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final language in ['en-US', 'pt-BR']) {
    testWidgets(
      '$language remains readable at 360px and double text size',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final p = await preferences();
        await p.update(p.value.copyWith(language: language));
        final service = _ConnectedService();
        addTearDown(service.dispose);
        await tester.pumpWidget(
          _localized(
            p,
            ClientScreen(
              preferences: p,
              service: service,
              aboutService: _About(),
            ),
            textScale: 2,
          ),
        );
        await tester.pumpAndSettle();
        final strings = await AppLocalizations.delegate.load(p.value.locale);
        expect(tester.takeException(), isNull);
        await drawer(tester);
        expect(find.byType(DropdownButton<String>), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(strings.mouse).last);
        await tester.pumpAndSettle();
        expect(find.byType(MouseControl), findsOneWidget);
        expect(tester.takeException(), isNull);
        await drawer(tester);
        await tester.tap(find.text(strings.media).last);
        await tester.pumpAndSettle();
        expect(find.byType(MediaControl), findsOneWidget);
        expect(tester.takeException(), isNull);
        await drawer(tester);
        await tester.tap(find.text(strings.keyboard).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await drawer(tester);
        await tester.tap(find.text(strings.settings));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final label in [
          strings.mouseSettings,
          strings.connectionSettings,
          strings.appearanceSettings,
        ]) {
          final tile = find.widgetWithText(ListTile, label);
          await tester.ensureVisible(tile);
          await tester.tap(tile);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
        }
        await drawer(tester);
        await tester.tap(find.text(strings.about));
        await tester.pumpAndSettle();
        expect(find.text('Leonardo Briquezi aka devpatok'), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(service.disconnects, 0);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets(
    'open settings dialogs follow language changes without losing a selection',
    (tester) async {
      final p = await preferences();
      await tester.pumpWidget(
        _localized(
          p,
          Scaffold(
            body: SettingsPage(
              preferences: p,
              onComputers: () {},
              onTestMouse: () {},
              onDiagnostics: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final english = await AppLocalizations.delegate.load(
        const Locale('en', 'US'),
      );
      final portuguese = await AppLocalizations.delegate.load(
        const Locale('pt', 'BR'),
      );
      await tester.tap(find.text(english.appearanceSettings));
      await tester.pumpAndSettle();
      await tester.tap(find.text(english.theme));
      await tester.pumpAndSettle();
      expect(find.byType(SimpleDialog), findsOneWidget);
      await p.update(p.value.copyWith(language: 'pt-BR'));
      await tester.pumpAndSettle();
      expect(find.text(portuguese.theme), findsWidgets);
      expect(find.text(english.theme), findsNothing);
      expect(p.value.themeMode, ThemeMode.dark);
      await tester.tap(find.text(portuguese.light));
      await tester.pumpAndSettle();
      expect(p.value.themeMode, ThemeMode.light);
      expect(find.byType(SimpleDialog), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'camera permission errors localize immediately at double text size',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final p = await preferences();
      await tester.pumpWidget(
        _localized(
          p,
          const Scaffold(
            body: PairingCameraError(
              code: MobileScannerErrorCode.permissionDenied,
            ),
          ),
          textScale: 2,
        ),
      );
      await tester.pumpAndSettle();
      final en = await AppLocalizations.delegate.load(const Locale('en', 'US'));
      final pt = await AppLocalizations.delegate.load(const Locale('pt', 'BR'));
      expect(find.text(en.cameraPermission), findsOneWidget);
      await p.update(p.value.copyWith(language: 'pt-BR'));
      await tester.pumpAndSettle();
      expect(find.text(pt.cameraPermission), findsOneWidget);
      expect(find.text(en.cameraPermission), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
