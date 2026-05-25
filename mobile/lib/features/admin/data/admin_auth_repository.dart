// AdminAuthRepository — owns the password → admin-token exchange. Lives in the admin feature on purpose:
// the main features/auth/ layer must not know about the admin gate (different auth context).
//
// /auth/admin-unlock/ is anonymous on the backend (the password IS the gate), so we call it via a bare
// Dio instance — we don't want the request riding either the main ApiClient (which would attach a buyer
// token) or AdminApiClient (which would attach a stale admin token + retry loop).
import 'package:dio/dio.dart';

import '../../../core/config/env.dart';
import 'admin_token_storage.dart';


/// Plain-data exception so the password dialog can render the server's message directly.
class AdminAuthException implements Exception {
  final String message;
  const AdminAuthException(this.message);
  @override String toString() => message;
}


class AdminAuthRepository {
  final AdminTokenStorage _tokens;
  final Dio _dio;                                    // bare Dio — no interceptors, no token injection
  AdminAuthRepository({required AdminTokenStorage tokens, Dio? dio})
      : _tokens = tokens,
        _dio = dio ?? Dio(BaseOptions(baseUrl: Env.apiBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 15),
            headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
            validateStatus: (s) => s != null && s < 500));

  /// POST /auth/admin-unlock/ — sends the password. On 200 we persist the returned JWT pair into the
  /// admin-only keystore (AdminTokenStorage) — NEVER into TokenStorage. Throws AdminAuthException on
  /// wrong password (401) or any other non-200 response so the password dialog can render the error.
  Future<void> unlock(String password) async {
    final r = await _dio.post('/auth/admin-unlock/', data: {'password': password});
    if (r.statusCode == 200) {
      await _tokens.writeBoth(access: r.data['access'] as String, refresh: r.data['refresh'] as String);
      return;
    }
    if (r.statusCode == 401) throw const AdminAuthException('Invalid password');
    final detail = (r.data is Map && r.data['detail'] is String) ? r.data['detail'] as String : null;
    throw AdminAuthException(detail ?? 'Admin unlock failed (HTTP ${r.statusCode})');
  }

  /// Clears admin tokens. Main app user session is untouched.
  Future<void> lock() => _tokens.clear();
}
