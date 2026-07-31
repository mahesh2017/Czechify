import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Keychain/keystore-backed Supabase session storage with migration from the
/// package's historical SharedPreferences default.
class SecureSupabaseLocalStorage extends LocalStorage {
  SecureSupabaseLocalStorage({
    required this.storageKey,
    FlutterSecureStorage? secureStorage,
  }) : _secure = secureStorage ?? const FlutterSecureStorage();
  final String storageKey;
  final FlutterSecureStorage _secure;

  @override
  Future<void> initialize() async {
    if (await _secure.containsKey(key: storageKey)) return;
    final preferences = await SharedPreferences.getInstance();
    final legacy = preferences.getString(storageKey);
    if (legacy == null) return;
    await _secure.write(key: storageKey, value: legacy);
    await preferences.remove(storageKey);
  }

  @override
  Future<bool> hasAccessToken() => _secure.containsKey(key: storageKey);
  @override
  Future<String?> accessToken() => _secure.read(key: storageKey);
  @override
  Future<void> persistSession(String value) =>
      _secure.write(key: storageKey, value: value);
  @override
  Future<void> removePersistedSession() => _secure.delete(key: storageKey);
}

class SecurePkceStorage extends GotrueAsyncStorage {
  SecurePkceStorage({FlutterSecureStorage? secureStorage})
    : _secure = secureStorage ?? const FlutterSecureStorage();
  static const _prefix = 'supabase-pkce-';
  final FlutterSecureStorage _secure;

  @override
  Future<String?> getItem({required String key}) async {
    final secureKey = '$_prefix$key';
    final current = await _secure.read(key: secureKey);
    if (current != null) return current;
    final preferences = await SharedPreferences.getInstance();
    final legacy = preferences.getString(key);
    if (legacy == null) return null;
    await _secure.write(key: secureKey, value: legacy);
    await preferences.remove(key);
    return legacy;
  }

  @override
  Future<void> setItem({required String key, required String value}) =>
      _secure.write(key: '$_prefix$key', value: value);
  @override
  Future<void> removeItem({required String key}) async {
    await _secure.delete(key: '$_prefix$key');
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(key);
  }
}
