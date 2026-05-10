// AuthRepository — owns all /api/v1/auth/* calls and the post-login token persistence flow.
import 'package:dio/dio.dart';

import '../../../core/auth/token_storage.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/user.dart';


/// Plain-data exception used by the UI layer — message is already user-friendly so screens can render it directly.
class AuthException implements Exception {
  final String message;
  final Map<String, List<String>>? fieldErrors;  // populated for 400s with per-field validation errors
  const AuthException(this.message, [this.fieldErrors]);
  @override String toString() => message;
}


class AuthRepository {
  final ApiClient _api;
  final TokenStorage _tokens;
  AuthRepository({required ApiClient api, required TokenStorage tokens}) : _api = api, _tokens = tokens;

  /// POST /auth/register/ — creates SUPPLIER or BUYER (ADMIN is server-only). Returns the created user.
  Future<User> register({required String email, required String fullName, required String password,
                         required String phone, required UserRole role}) async {
    final r = await _api.dio.post('/auth/register/', data: {
      'email': email, 'full_name': fullName, 'password': password, 'phone': phone,
      'role': role == UserRole.supplier ? 'SUPPLIER' : 'BUYER',
    });
    if (r.statusCode == 201) return User.fromJson(r.data as Map<String, dynamic>);
    throw _toAuthException(r);
  }

  /// POST /auth/login/ — exchanges credentials for JWT pair, persists both tokens, then loads + returns the user.
  Future<User> login({required String email, required String password}) async {
    final r = await _api.dio.post('/auth/login/', data: {'email': email, 'password': password});
    if (r.statusCode != 200) throw _toAuthException(r);
    await _tokens.writeBoth(access: r.data['access'] as String, refresh: r.data['refresh'] as String);
    return fetchMe();  // reuse the /me path so the User shape is identical to other code paths
  }

  /// GET /auth/me/ — used at app start (resume session) and after login. Throws AuthException on 401 so callers route to login.
  Future<User> fetchMe() async {
    final r = await _api.dio.get('/auth/me/');
    if (r.statusCode == 200) return User.fromJson(r.data as Map<String, dynamic>);
    throw _toAuthException(r);
  }

  /// PATCH /auth/me/ — updates the editable subset of the user record (full_name, phone). Email/role stay server-managed.
  Future<User> updateMe({String? fullName, String? phone}) async {
    final r = await _api.dio.patch('/auth/me/', data: {
      'full_name': ?fullName,  // Dart 3.5 null-aware map entry — omitted entirely if fullName is null
      'phone': ?phone,
    });
    if (r.statusCode == 200) return User.fromJson(r.data as Map<String, dynamic>);
    throw _toAuthException(r);
  }

  /// Local-only logout — backend has no logout endpoint (JWTs are stateless until expiry).
  Future<void> logout() => _tokens.clear();

  /// DELETE /auth/me/ — permanently removes the user's account on the server. Caller logs out afterward.
  /// Surfaces the server's 409 message ("cancel active orders first") via AuthException.
  Future<void> deleteAccount() async {
    final r = await _api.dio.delete('/auth/me/');
    if (r.statusCode != 204) throw _toAuthException(r);
  }

  /// Translate Dio responses + DRF error shapes into a uniform AuthException with per-field validation messages.
  AuthException _toAuthException(Response r) {
    if (r.data is Map<String, dynamic>) {
      final m = r.data as Map<String, dynamic>;
      // DRF returns {field: [msg, ...]} for 400, or {detail: msg} for 401/403; normalize both
      if (m['detail'] is String) return AuthException(m['detail'] as String);
      final fieldErrors = <String, List<String>>{};
      m.forEach((k, v) { if (v is List) fieldErrors[k] = v.map((e) => e.toString()).toList(); });
      return AuthException(_summarize(fieldErrors), fieldErrors);
    }
    return AuthException('Request failed (HTTP ${r.statusCode})');
  }

  String _summarize(Map<String, List<String>> errs) =>
      errs.isEmpty ? 'Unknown error' : errs.entries.map((e) => '${e.key}: ${e.value.join(", ")}').join('\n');
}
