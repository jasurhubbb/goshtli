import 'package:dio/dio.dart';

import '../api/api_exception.dart';
import 'token_storage.dart';
import '../models/user.dart';

/// Firebase Phone Auth → backend JWT bridge. Used identically by buyer + partner apps.
///
/// Flow:
///   1. Mobile UI calls FirebaseAuth.instance.verifyPhoneNumber → SMS sent.
///   2. User enters OTP → signInWithCredential → Firebase ID token.
///   3. Call [FirebasePhoneBridge.exchange] with that token.
///   4. Backend returns either:
///        - `{new_user: true, phone}` → push to /auth/details to collect full_name
///        - `{new_user: false, access, refresh}` → existing user; tokens persisted; user fetched
///
/// Tokens are written to the supplied [TokenStorage] on existing-user paths so subsequent ApiClient
/// requests pick them up automatically.
class FirebasePhoneBridge {
  final Dio _dio;
  final TokenStorage _tokens;

  FirebasePhoneBridge({required Dio dio, required TokenStorage tokens})
      : _dio = dio, _tokens = tokens;

  /// Returns a tri-state record indicating what the UI should do next.
  Future<({User? user, bool isNew, String phone})> exchange(String firebaseIdToken) async {
    final r = await _dio.post('/auth/firebase-phone-login/', data: {
      'firebase_id_token': firebaseIdToken,
    });
    if (r.statusCode != 200) {
      final detail = r.data is Map ? (r.data as Map)['detail']?.toString() : null;
      throw ApiException(detail ?? 'Firebase bridge failed (HTTP ${r.statusCode})');
    }
    final data = r.data as Map<String, dynamic>;
    if (data['new_user'] == true) {
      return (user: null, isNew: true, phone: data['phone'] as String);
    }
    final access = data['access'] as String?;
    final refresh = data['refresh'] as String?;
    if (access == null || refresh == null) {
      throw ApiException('Backend returned an invalid response (missing tokens).');
    }
    await _tokens.writeBoth(access: access, refresh: refresh);
    // Fetch the user with the new token so callers don't have to.
    final me = await _dio.get('/auth/me/',
        options: Options(headers: {'Authorization': 'Bearer $access'}));
    final user = User.fromJson(me.data as Map<String, dynamic>);
    return (user: user, isNew: false, phone: user.phone);
  }

  /// Completes new-user signup: POST /auth/phone-register/ with the verified phone + full_name.
  /// Backend creates a BUYER by default; the partner app overrides `role` via the wizard's submit.
  Future<User> phoneRegister({
    required String phone,
    required String fullName,
    String businessName = '',
    String? roleOverride,
  }) async {
    final r = await _dio.post('/auth/phone-register/', data: {
      'phone': phone,
      'full_name': fullName,
      'business_name': businessName,
      if (roleOverride != null) 'role': roleOverride,
    });
    if (r.statusCode != 201) {
      final detail = r.data is Map ? (r.data as Map)['detail']?.toString() : null;
      throw ApiException(detail ?? 'Registration failed (HTTP ${r.statusCode})');
    }
    final data = r.data as Map<String, dynamic>;
    final access = data['access'] as String;
    final refresh = data['refresh'] as String;
    await _tokens.writeBoth(access: access, refresh: refresh);
    final me = await _dio.get('/auth/me/',
        options: Options(headers: {'Authorization': 'Bearer $access'}));
    return User.fromJson(me.data as Map<String, dynamic>);
  }
}
