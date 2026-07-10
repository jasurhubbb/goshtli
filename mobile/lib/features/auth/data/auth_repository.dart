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

  /// PATCH /auth/me/ — updates the editable subset of the user record. Email/role stay server-managed.
  /// v3.3 adds first/last/patronymic/dob/gender; full_name is server-recomputed from first+last when either
  /// is supplied (see UserSerializer.update), so callers normally don't pass fullName once the structured
  /// fields are filled.
  Future<User> updateMe({
    String? fullName, String? phone,
    String? firstName, String? lastName, String? patronymic,
    String? dateOfBirth, UserGender? gender,
  }) async {
    final r = await _api.dio.patch('/auth/me/', data: {
      'full_name': ?fullName,  // Dart 3.5 null-aware map entry — omitted entirely if fullName is null
      'phone': ?phone,
      'first_name': ?firstName,
      'last_name': ?lastName,
      'patronymic': ?patronymic,
      'date_of_birth': ?dateOfBirth,
      // Gender goes over the wire as 'M' / 'F' / '' (empty string clears the field server-side).
      if (gender != null) 'gender': gender == UserGender.male ? 'M' : 'F',
    });
    if (r.statusCode == 200) return User.fromJson(r.data as Map<String, dynamic>);
    throw _toAuthException(r);
  }

  /// Local-only logout — backend has no logout endpoint (JWTs are stateless until expiry).
  Future<void> logout() => _tokens.clear();


  // ---------- Phone-based auth (v3.2) ----------

  /// POST /auth/phone-check/ — returns whether an account with this phone already exists.
  /// Used by the mobile flow to branch between "log in this existing user" vs "ask for name + register".
  Future<bool> phoneCheck(String phone) async {
    final r = await _api.dio.post('/auth/phone-check/', data: {'phone': phone});
    if (r.statusCode == 200) return r.data['exists'] as bool;
    throw _toAuthException(r);
  }

  /// POST /auth/phone-login/ — passwordless login by phone. Backend returns JWT pair; persist + fetchMe.
  Future<User> phoneLogin(String phone) async {
    final r = await _api.dio.post('/auth/phone-login/', data: {'phone': phone});
    if (r.statusCode != 200) throw _toAuthException(r);
    await _tokens.writeBoth(access: r.data['access'] as String, refresh: r.data['refresh'] as String);
    return fetchMe();
  }

  /// POST /auth/phone-register/ — creates a buyer account by phone + name (+ optional business). Returns JWT,
  /// persists tokens, fetches the User record so callers can use it immediately.
  Future<User> phoneRegister({required String phone, required String fullName, String businessName = ''}) async {
    final r = await _api.dio.post('/auth/phone-register/', data: {
      'phone': phone, 'full_name': fullName,
      if (businessName.isNotEmpty) 'business_name': businessName,
    });
    if (r.statusCode != 201) throw _toAuthException(r);
    await _tokens.writeBoth(access: r.data['access'] as String, refresh: r.data['refresh'] as String);
    return fetchMe();
  }


  /// DELETE /auth/me/ — permanently removes the user's account on the server. Caller logs out afterward.
  /// Surfaces the server's 409 message ("cancel active orders first") via AuthException.
  Future<void> deleteAccount() async {
    final r = await _api.dio.delete('/auth/me/');
    if (r.statusCode != 204) throw _toAuthException(r);
  }


  // ---------- Telegram Phone Verification (v3.9.16) ----------
  //
  // Replaces Firebase SMS OTP. Two steps:
  //   1. telegramStart(phone) → backend opens a verification session, returns the t.me deep-link the
  //      "Botga o'tish" button opens. The user shares their contact in the bot and gets a code.
  //   2. telegramVerify(sessionToken, code) → backend checks the code and returns the SAME shape the old
  //      Firebase bridge did (existing user → tokens persisted; new user → phone for /auth/details).

  /// POST /auth/telegram/start/ — opens a session for `phone`. Returns the session token (passed to verify)
  /// and the bot deep-link URL for the button. No tokens/user involved; enumeration-safe on the backend.
  Future<({String sessionToken, String botUrl})> telegramStart(String phone) async {
    final r = await _api.dio.post('/auth/telegram/start/', data: {'phone': phone});
    if (r.statusCode != 200) throw _toAuthException(r);
    final data = r.data as Map<String, dynamic>;
    return (sessionToken: data['session_token'] as String, botUrl: data['bot_url'] as String);
  }

  /// POST /auth/telegram/verify/ — trades the 6-digit code for a session. Existing user → tokens persisted
  /// + user fetched (isNew=false); unknown phone → isNew=true + phone for the /auth/details name step.
  Future<({User? user, bool isNew, String phone})> telegramVerify(String sessionToken, String code) async {
    final r = await _api.dio.post('/auth/telegram/verify/',
        data: {'session_token': sessionToken, 'code': code});
    if (r.statusCode != 200) throw _toAuthException(r);
    final data = r.data as Map<String, dynamic>;
    if (data['new_user'] == true) {
      // New user → no tokens yet; CodeEntryScreen pushes /auth/details next.
      return (user: null, isNew: true, phone: data['phone'] as String);
    }
    // Existing user — persist tokens BEFORE fetchMe so the session can recover on next launch even if
    // fetchMe fails here (tokens stay on disk; _resume() picks them up).
    final access = data['access'] as String?;
    final refresh = data['refresh'] as String?;
    if (access == null || refresh == null) {
      throw const AuthException('Backend returned an invalid response (missing tokens).');
    }
    await _tokens.writeBoth(access: access, refresh: refresh);
    final user = await fetchMe();
    return (user: user, isNew: false, phone: user.phone);
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
