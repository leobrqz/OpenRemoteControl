import 'dart:convert';

typedef ClientStorageRead = Future<String?> Function();
typedef ClientStorageWrite = Future<void> Function(String value);

class HostClientRecord {
  const HostClientRecord({
    required this.id,
    required this.name,
    required this.tokenHash,
    this.model,
    this.androidVersion,
  });

  final String id;
  final String name;
  final String tokenHash;
  final String? model;
  final String? androidVersion;

  HostClientRecord withMetadata({
    String? name,
    String? model,
    String? androidVersion,
  }) => HostClientRecord(
    id: id,
    name: name ?? this.name,
    tokenHash: tokenHash,
    model: model ?? this.model,
    androidVersion: androidVersion ?? this.androidVersion,
  );
}

class HostClientRepository {
  HostClientRepository({required this.read, required this.write});

  static const storageKey = 'orc.host.clients.v1';

  final ClientStorageRead read;
  final ClientStorageWrite write;

  Future<Map<String, HostClientRecord>> load() async {
    final stored = await read();
    if (stored == null) return {};
    final decoded = jsonDecode(stored);
    if (decoded is! List) return {};

    final clients = <String, HostClientRecord>{};
    for (final row in decoded) {
      if (row is! Map<String, dynamic> ||
          row['id'] is! String ||
          row['name'] is! String ||
          row['tokenHash'] is! String) {
        continue;
      }
      final record = HostClientRecord(
        id: row['id'] as String,
        name: row['name'] as String,
        tokenHash: row['tokenHash'] as String,
        model: row['model'] is String ? row['model'] as String : null,
        androidVersion: row['androidVersion'] is String
            ? row['androidVersion'] as String
            : null,
      );
      clients[record.id] = record;
    }
    return clients;
  }

  Future<void> save(Iterable<HostClientRecord> clients) async {
    final records = clients
        .map(
          (client) => {
            'id': client.id,
            'name': client.name,
            'tokenHash': client.tokenHash,
            if (client.model != null) 'model': client.model,
            if (client.androidVersion != null)
              'androidVersion': client.androidVersion,
          },
        )
        .toList(growable: false);
    await write(jsonEncode(records));
  }

  Future<HostClientRecord> updateMetadata(
    Map<String, HostClientRecord> clients,
    HostClientRecord client, {
    String? name,
    String? model,
    String? androidVersion,
  }) async {
    if (!identical(clients[client.id], client)) return client;
    final updated = client.withMetadata(
      model: model ?? client.model,
      androidVersion: androidVersion ?? client.androidVersion,
      name: name ?? client.name,
    );
    if (updated.name == client.name &&
        updated.model == client.model &&
        updated.androidVersion == client.androidVersion) {
      return client;
    }
    await save([
      for (final record in clients.values)
        if (record.id != client.id) record,
      updated,
    ]);
    if (identical(clients[client.id], client)) clients[client.id] = updated;
    return clients[client.id] ?? client;
  }
}
