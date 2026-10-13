import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_remote_control/src/client/about_service.dart';
import 'package:open_remote_control/src/client/client_screen.dart';
import 'package:open_remote_control/src/client/client_service.dart';
import 'package:open_remote_control/src/client/preferences/client_preferences.dart';
import 'package:open_remote_core/open_remote_core.dart';

class _FakeService extends RemoteClientService {
  @override
  Future<List<SavedHost>> loadSavedHosts() async => const [];
  @override
  Future<List<DiscoveredHost>> discoverHosts() async => const [];
  @override
  Future<void> updateDiscoveredAddresses() async {}
}

class _FakeAboutService extends AboutService {
  _FakeAboutService({this.openResult = true});

  final bool openResult;
  final opened = <Uri>[];

  @override
  Future<String> installedVersion() async => '9.8.7+42';

  @override
  Future<bool> openExternal(Uri uri) async {
    opened.add(uri);
    return openResult;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('open_remote/preferences'),
          (_) async => null,
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

  testWidgets(
    'Sobre fica fixo no rodapé em tela baixa e funciona desconectado',
    (tester) async {
      tester.view.physicalSize = const Size(360, 420);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final preferences = PreferencesController();
      await preferences.update(
        preferences.value.copyWith(
          automaticDiscovery: false,
          updateServerAddress: false,
        ),
      );
      final about = _FakeAboutService();
      await tester.pumpWidget(
        MaterialApp(
          home: ClientScreen(
            preferences: preferences,
            service: _FakeService(),
            aboutService: about,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      final aboutTile = find.ancestor(
        of: find.text('Sobre'),
        matching: find.byType(ListTile),
      );
      expect(aboutTile, findsOneWidget);
      expect(
        tester.getRect(aboutTile).bottom,
        closeTo(tester.getRect(find.byType(Drawer)).bottom, 1),
      );
      expect(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.byType(ListView),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Sobre'));
      await tester.pumpAndSettle();

      expect(find.text('Open Remote Control'), findsOneWidget);
      expect(find.text('9.8.7+42'), findsOneWidget);
      expect(find.text('Android'), findsOneWidget);
      expect(find.text('GPL-3.0-only'), findsOneWidget);
      expect(find.text('Leonardo Briquezi aka devpatok'), findsOneWidget);
      expect(about.opened, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Computadores'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      preferences.dispose();
    },
  );

  testWidgets('links open externally and show a message if opening fails', (
    tester,
  ) async {
    final preferences = PreferencesController();
    await preferences.update(
      preferences.value.copyWith(
        automaticDiscovery: false,
        updateServerAddress: false,
      ),
    );
    final about = _FakeAboutService(openResult: false);
    await tester.pumpWidget(
      MaterialApp(
        home: ClientScreen(
          preferences: preferences,
          service: _FakeService(),
          aboutService: about,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sobre'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Site oficial'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Site oficial'));
    await tester.pumpAndSettle();
    expect(
      about.opened.single,
      Uri.parse('https://openremotecontrol.sourceforge.io/'),
    );
    expect(find.text('Não foi possível abrir o link.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    preferences.dispose();
  });
}
