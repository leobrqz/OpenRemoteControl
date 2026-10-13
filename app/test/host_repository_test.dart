import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_remote_control/src/client/repositories/host_repository.dart';
import 'package:open_remote_core/open_remote_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final publicKey = encodeBytes(List<int>.filled(32, 1));
  Map<String, Object?> profile(String id) => {
    'serverId': id,
    'name': 'Saved PC',
    'addresses': ['192.168.1.2'],
    'port': 47652,
    'signingPublicKey': publicKey,
    'clientId': 'saved-client',
    'clientToken': 'saved-token',
  };

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('reads existing profiles and credentials without migration', () async {
    FlutterSecureStorage.setMockInitialValues({
      'orc.client.hosts.v1': jsonEncode([profile('pc')]),
      'orc.client.manual-endpoint.v1': jsonEncode({
        'address': '192.168.1.2',
        'port': 47652,
      }),
    });
    final repository = SecureHostRepository();
    final hosts = await repository.loadSavedHosts();
    expect(hosts.single.serverId, 'pc');
    expect(hosts.single.signingPublicKey, publicKey);
    expect(
      (await repository.readProfiles())['pc']!['clientToken'],
      'saved-token',
    );
    expect(await repository.loadManualEndpoint(), {
      'address': '192.168.1.2',
      'port': 47652,
    });
  });

  test(
    'discovery refresh preserves authorization and verifies identity',
    () async {
      final repository = SecureHostRepository();
      await repository.saveProfile(profile('pc'));
      DiscoveredHost discovered(String key) => DiscoveredHost(
        serverId: 'pc',
        name: 'Renamed PC',
        addresses: ['192.168.1.9'],
        port: 47652,
        signingPublicKey: key,
      );
      await repository.updateDiscoveredAddresses([discovered('different-key')]);
      expect((await repository.loadSavedHosts()).single.addresses, [
        '192.168.1.2',
      ]);
      await repository.updateDiscoveredAddresses([discovered(publicKey)]);
      final host = (await repository.loadSavedHosts()).single;
      expect(host.name, 'Renamed PC');
      expect(host.addresses, ['192.168.1.9']);
      expect(
        (await repository.readProfiles())['pc']!['clientToken'],
        'saved-token',
      );
    },
  );

  test('forgetting one PC keeps other profiles and manual endpoint', () async {
    final repository = SecureHostRepository();
    await repository.saveProfile(profile('one'));
    await repository.saveProfile(profile('two'));
    await repository.saveManualEndpoint('192.168.1.7', 47652);
    await repository.forgetHost('one');
    expect((await repository.loadSavedHosts()).single.serverId, 'two');
    expect((await repository.loadManualEndpoint())!['address'], '192.168.1.7');
  });

  test('malformed stored data falls back to an empty host list', () async {
    FlutterSecureStorage.setMockInitialValues({
      'orc.client.hosts.v1': '{',
      'orc.client.manual-endpoint.v1': jsonEncode({
        'address': 7,
        'port': 'bad',
      }),
    });
    final repository = SecureHostRepository();
    expect(await repository.loadSavedHosts(), isEmpty);
    expect(await repository.readProfiles(), isEmpty);
    expect(await repository.loadManualEndpoint(), isNull);
  });
}
