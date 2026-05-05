// Thin wrapper around flutter_secure_storage — keeps token I/O in one file so we never sprinkle key-strings across the codebase.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';


class TokenStorage {
  // Single keychain/keystore item per token; values are encrypted at rest by the OS keychain on iOS / EncryptedSharedPreferences on Android
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  final FlutterSecureStorage _storage;
  TokenStorage([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  Future<String?> readAccess() => _storage.read(key: _accessKey);
  Future<String?> readRefresh() => _storage.read(key: _refreshKey);

  /// Persist both tokens after a successful login or refresh-rotation.
  Future<void> writeBoth({required String access, required String refresh}) async {
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  Future<void> writeAccess(String access) => _storage.write(key: _accessKey, value: access);

  /// Wipe both — called on logout, on refresh failure, or when the user account is deactivated server-side.
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
