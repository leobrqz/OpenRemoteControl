import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class PreferencesRepository {
  Future<String?> read();
  Future<void> write(String value);
}

class SecurePreferencesRepository implements PreferencesRepository {
  SecurePreferencesRepository({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const storageKey = 'orc.client.preferences.v1';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: storageKey);

  @override
  Future<void> write(String value) =>
      _storage.write(key: storageKey, value: value);
}
