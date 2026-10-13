import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:open_remote_core/open_remote_core.dart';

import '../models/saved_host.dart';

abstract class HostRepository {
  Future<List<SavedHost>> loadSavedHosts();
  Future<Map<String, dynamic>?> loadManualEndpoint();
  Future<void> saveManualEndpoint(String address, int port);
  Future<Map<String, Map<String, dynamic>>> readProfiles();
  Future<void> saveProfile(Map<String, Object?> profile);
  Future<void> writeProfiles(Map<String, Map<String, dynamic>> profiles);
  Future<void> forgetHost(String serverId);
  Future<void> updateDiscoveredAddresses(List<DiscoveredHost> hosts);
}

class SecureHostRepository implements HostRepository {
  SecureHostRepository({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  static const _hostsStorageKey = 'orc.client.hosts.v1';
  static const _manualEndpointStorageKey = 'orc.client.manual-endpoint.v1';

  @override
  Future<void> saveManualEndpoint(String address, int port) => _storage.write(
    key: _manualEndpointStorageKey,
    value: jsonEncode({'address': address, 'port': port}),
  );

  @override
  Future<Map<String, dynamic>?> loadManualEndpoint() async {
    final stored = await _storage.read(key: _manualEndpointStorageKey);
    if (stored == null) return null;
    try {
      final decoded = jsonDecode(stored);
      if (decoded is! Map<String, dynamic> ||
          decoded['address'] is! String ||
          decoded['port'] is! int) {
        return null;
      }
      return decoded;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<List<SavedHost>> loadSavedHosts() async {
    final stored = await _storage.read(key: _hostsStorageKey);
    if (stored == null) return const [];
    try {
      final decoded = jsonDecode(stored);
      if (decoded is! List) return const [];
      final result = <SavedHost>[];
      for (final row in decoded) {
        if (row is! Map<String, dynamic> ||
            row['serverId'] is! String ||
            row['name'] is! String ||
            row['addresses'] is! List ||
            row['port'] is! int ||
            row['signingPublicKey'] is! String) {
          continue;
        }
        final addresses = (row['addresses'] as List)
            .whereType<String>()
            .where(isPrivateIpv4)
            .toList(growable: false);
        if (addresses.isEmpty) continue;
        decodeBytes(row['signingPublicKey'], exactLength: 32);
        result.add(
          SavedHost(
            serverId: row['serverId'] as String,
            name: row['name'] as String,
            addresses: addresses,
            port: row['port'] as int,
            signingPublicKey: row['signingPublicKey'] as String,
          ),
        );
      }
      return result;
    } on FormatException {
      return const [];
    }
  }

  @override
  Future<Map<String, Map<String, dynamic>>> readProfiles() async {
    final stored = await _storage.read(key: _hostsStorageKey);
    if (stored == null) return {};
    try {
      final decoded = jsonDecode(stored);
      if (decoded is! List) return {};
      return {
        for (final row in decoded)
          if (row is Map<String, dynamic> &&
              row['serverId'] is String &&
              row['clientId'] is String &&
              row['clientToken'] is String)
            row['serverId'] as String: row,
      };
    } on FormatException {
      return {};
    }
  }

  @override
  Future<void> saveProfile(Map<String, Object?> profile) async {
    final profiles = await readProfiles();
    profiles[profile['serverId']! as String] = profile;
    await writeProfiles(profiles);
  }

  @override
  Future<void> writeProfiles(Map<String, Map<String, dynamic>> profiles) async {
    await _storage.write(
      key: _hostsStorageKey,
      value: jsonEncode(profiles.values.toList(growable: false)),
    );
  }

  @override
  Future<void> forgetHost(String serverId) async {
    final profiles = await readProfiles();
    profiles.remove(serverId);
    await writeProfiles(profiles);
  }

  @override
  Future<void> updateDiscoveredAddresses(List<DiscoveredHost> hosts) async {
    final profiles = await readProfiles();
    var changed = false;
    for (final host in hosts) {
      final profile = profiles[host.serverId];
      if (profile == null ||
          profile['signingPublicKey'] != host.signingPublicKey) {
        continue;
      }
      profile['addresses'] = host.addresses;
      profile['port'] = host.port;
      profile['name'] = host.name;
      changed = true;
    }
    if (changed) await writeProfiles(profiles);
  }
}
