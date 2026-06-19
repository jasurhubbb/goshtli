import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper around flutter_secure_storage — keeps token I/O in one file so the keystrings stay
/// consistent across buyer + partner apps.
///
/// Both apps store under the same keystore namespace by default. If we ever want one app to log out
/// without affecting the other, pass a custom `keyPrefix` to scope (e.g. 'partner_').
class TokenStorage {
  static const _defaultAccessKey = 'access_token';
  static const _defaultRefreshKey = 'refresh_token';

  final FlutterSecureStorage _storage;
  final String _accessKey;
  final String _refreshKey;

  TokenStorage({FlutterSecureStorage? storage, String keyPrefix = ''})
      : _storage = storage ?? const FlutterSecureStorage(),
        _accessKey = '$keyPrefix$_defaultAccessKey',
        _refreshKey = '$keyPrefix$_defaultRefreshKey';

  Future<String?> readAccess() => _storage.read(key: _accessKey);
  Future<String?> readRefresh() => _storage.read(key: _refreshKey);

  Future<void> writeBoth({required String access, required String refresh}) async {
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  Future<void> writeAccess(String access) => _storage.write(key: _accessKey, value: access);

  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
