import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_remote_server/src/host/host_client_repository.dart';

void main() {
  test(
    'metadata refresh cannot restore a concurrently revoked client',
    () async {
      final writing = Completer<void>();
      final finish = Completer<void>();
      final repository = HostClientRepository(
        read: () async => null,
        write: (_) async {
          writing.complete();
          await finish.future;
        },
      );
      const client = HostClientRecord(
        id: 'phone-id',
        name: 'Old phone',
        tokenHash: 'secret-hash',
      );
      final clients = {client.id: client};
      final update = repository.updateMetadata(
        clients,
        client,
        name: 'New name',
      );
      await writing.future;
      clients.remove(client.id);
      finish.complete();
      await update;
      expect(clients, isEmpty);
    },
  );
  test(
    'loads legacy paired clients without changing their credentials',
    () async {
      var stored = jsonEncode([
        {'id': 'phone-id', 'name': 'Old phone', 'tokenHash': 'secret-hash'},
      ]);
      var writes = 0;
      final repository = HostClientRepository(
        read: () async => stored,
        write: (value) async {
          writes++;
          stored = value;
        },
      );

      final clients = await repository.load();
      final legacy = clients['phone-id']!;
      expect(legacy.name, 'Old phone');
      expect(legacy.model, isNull);
      expect(legacy.androidVersion, isNull);
      expect(legacy.tokenHash, 'secret-hash');

      final unchanged = await repository.updateMetadata(
        clients,
        legacy,
        name: 'Old phone',
      );
      expect(identical(unchanged, legacy), isTrue);
      expect(writes, 0);

      final refreshed = await repository.updateMetadata(
        clients,
        legacy,
        name: 'Pixel 9',
        model: 'Google Pixel 9',
        androidVersion: '16',
      );
      expect(refreshed.id, 'phone-id');
      expect(refreshed.tokenHash, 'secret-hash');
      expect(refreshed.name, 'Pixel 9');
      expect(refreshed.model, 'Google Pixel 9');
      expect(refreshed.androidVersion, '16');
      expect(writes, 1);

      final reloaded = (await repository.load())['phone-id']!;
      expect(reloaded.id, 'phone-id');
      expect(reloaded.tokenHash, 'secret-hash');
      expect(reloaded.name, 'Pixel 9');
      expect(reloaded.model, 'Google Pixel 9');
      expect(reloaded.androidVersion, '16');
    },
  );

  test('ignores malformed optional persisted metadata', () async {
    final repository = HostClientRepository(
      read: () async => jsonEncode([
        {
          'id': 'phone-id',
          'name': 'Phone',
          'tokenHash': 'secret-hash',
          'model': 42,
          'androidVersion': false,
        },
      ]),
      write: (_) async {},
    );

    final client = (await repository.load())['phone-id']!;
    expect(client.name, 'Phone');
    expect(client.model, isNull);
    expect(client.androidVersion, isNull);
    expect(client.tokenHash, 'secret-hash');
  });

  test(
    'keeps the authenticated record unchanged when metadata storage fails',
    () async {
      final repository = HostClientRepository(
        read: () async => jsonEncode([
          {'id': 'phone-id', 'name': 'Old phone', 'tokenHash': 'secret-hash'},
        ]),
        write: (_) async => throw StateError('storage unavailable'),
      );
      final clients = await repository.load();
      final legacy = clients['phone-id']!;

      await expectLater(
        repository.updateMetadata(
          clients,
          legacy,
          name: 'Pixel 9',
          model: 'Google Pixel 9',
        ),
        throwsStateError,
      );

      expect(identical(clients['phone-id'], legacy), isTrue);
      expect(clients['phone-id']!.name, 'Old phone');
      expect(clients['phone-id']!.model, isNull);
      expect(clients['phone-id']!.tokenHash, 'secret-hash');
    },
  );
}
