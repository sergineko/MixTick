import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Separate namespaces per backend; no session/verifier in preferences or logs.
class SecureAuthStorage extends LocalStorage {
  SecureAuthStorage(String endpoint, {FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          ),
      prefix =
          'mixtick.auth.${Uri.parse(endpoint).host}.${Uri.parse(endpoint).port}';
  final FlutterSecureStorage _storage;
  Future<void> _writes = Future.value();
  final String prefix;
  Future<String?> read(String key) async {
    await _writes;
    return _storage.read(key: '$prefix.$key');
  }

  Future<void> _mutate(Future<void> Function() operation) {
    final result = _writes.catchError((Object _) {}).then((_) => operation());
    _writes = result;
    return result;
  }

  Future<void> write(String key, String value) =>
      _mutate(() => _storage.write(key: '$prefix.$key', value: value));
  Future<void> remove(String key) =>
      _mutate(() => _storage.delete(key: '$prefix.$key'));
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> hasAccessToken() async => await read('session') != null;
  @override
  Future<String?> accessToken() => read('session');
  @override
  Future<void> persistSession(String persistSessionString) =>
      write('session', persistSessionString);
  @override
  Future<void> removePersistedSession() => remove('session');
}

class SecurePkceStorage extends GotrueAsyncStorage {
  SecurePkceStorage(this.storage);
  final SecureAuthStorage storage;
  @override
  Future<String?> getItem({required String key}) => storage.read('pkce.$key');
  @override
  Future<void> removeItem({required String key}) => storage.remove('pkce.$key');
  @override
  Future<void> setItem({required String key, required String value}) =>
      storage.write('pkce.$key', value);
}
