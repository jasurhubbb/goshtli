import 'package:dio/dio.dart';

import '../api/api_exception.dart';
import 'token_storage.dart';
import '../models/user.dart';

/// Partner-app auth bridge. v3.9.16 — partners (supplier / qassob / courier) no longer self-register; ops
/// provisions them a phone + password (see backend provision_supplier / provision_qassob / provision_courier).
/// This trades those credentials for a backend JWT pair and loads the user. Firebase SMS is gone.
class AuthBridge {
  final Dio _dio;
  final TokenStorage _tokens;

  AuthBridge({required Dio dio, required TokenStorage tokens})
      : _dio = dio, _tokens = tokens;

  /// POST /auth/phone-password-login/ — admin-issued phone + password → JWT pair. Persists both tokens,
  /// then fetches + returns the User so the caller can route by role. Throws ApiException with the backend's
  /// (generic, enumeration-safe) message on a bad credential / disabled account.
  Future<User> phonePasswordLogin({required String phone, required String password}) async {
    final r = await _dio.post('/auth/phone-password-login/', data: {'phone': phone, 'password': password});
    if (r.statusCode != 200) {
      final detail = r.data is Map ? (r.data as Map)['detail']?.toString() : null;
      throw ApiException(detail ?? 'Login failed (HTTP ${r.statusCode})');
    }
    final data = r.data as Map<String, dynamic>;
    final access = data['access'] as String?;
    final refresh = data['refresh'] as String?;
    if (access == null || refresh == null) {
      throw ApiException('Backend returned an invalid response (missing tokens).');
    }
    await _tokens.writeBoth(access: access, refresh: refresh);
    final me = await _dio.get('/auth/me/',
        options: Options(headers: {'Authorization': 'Bearer $access'}));
    return User.fromJson(me.data as Map<String, dynamic>);
  }
}
