// AdminTokenStorage — separate keychain keys for the admin gate's JWT pair.
//
// Lives in a different namespace from TokenStorage (the main app's user session) so the admin tokens
// can coexist with whatever user is logged into the main app. Anonymous browsing, buyer login, and the
// admin gate are three independent auth contexts; this storage owns the third one.
//
// Tokens persist across app restarts (admin can re-enter /admin without re-typing the password) but never
// flow into the main ApiClient — they're consumed exclusively by AdminApiClient.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';


class AdminTokenStorage {
  // Distinct keys from TokenStorage so the two contexts never collide
  static const _accessKey = 'admin_access_token';
  static const _refreshKey = 'admin_refresh_token';

  final FlutterSecureStorage _storage;
  AdminTokenStorage([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  Future<String?> readAccess() => _storage.read(key: _accessKey);
  Future<String?> readRefresh() => _storage.read(key: _refreshKey);

  Future<void> writeBoth({required String access, required String refresh}) async {
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  /// Clears ONLY the admin tokens. Main app user session is untouched.
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }

  /// Quick presence check — used at app start to decide whether /admin can be entered without re-prompting.
  Future<bool> hasTokens() async => (await readAccess()) != null;
}
