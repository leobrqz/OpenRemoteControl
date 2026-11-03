import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_remote_control/l10n/app_localizations.dart';
import 'package:open_remote_control/src/client/client_service.dart';
import 'package:open_remote_control/src/client/computers_page.dart';
import 'package:open_remote_core/open_remote_core.dart';

class _Service extends RemoteClientService {
  @override
  List<DiscoveredHost> get discoveredHosts => const [
    DiscoveredHost(
      serverId: 'pc',
      name: 'PC',
      addresses: ['192.168.1.10'],
      port: 47652,
      signingPublicKey: 'key',
    ),
  ];
}

void main() {
  testWidgets('shows both local and persistent routes for the same PC', (
    tester,
  ) async {
    final service = _Service();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ComputersPage(
            service: service,
            savedHosts: const [
              SavedHost(
                serverId: 'pc',
                name: 'PC',
                addresses: ['192.168.1.10'],
                port: 47652,
                signingPublicKey: 'key',
                remoteEndpoint: 'remote',
              ),
            ],
            loading: false,
            showErrors: true,
            onConnectSaved: (_) {},
            onConnectDiscovered: (_) {},
            onOpenControls: () {},
            onForget: (_) {},
            onAdd: () {},
          ),
        ),
      ),
    );
    expect(find.textContaining('Local · Persistent'), findsOneWidget);
    expect(find.text('PC'), findsOneWidget);
    service.dispose();
  });
}
