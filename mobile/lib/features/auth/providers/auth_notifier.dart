// AuthNotifier — single source of truth for whether the user is logged in.
//
// v3 pivot: fresh installs and logout drop into AuthAnonymous (not AuthUnauthenticated). The app's home tab is
// reachable without a session; auth-required actions surface a sign-in sheet on demand.
//
// v2 Milestone E.5 hook: on successful login/register/resume we ask the OS for notification permission and
// register this device's FCM token with the backend so push events reach the right user.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/token_storage.dart';
import '../../../core/push/fcm_service.dart';
import '../../../shared/models/user.dart';
import '../data/auth_repository.dart';
import 'auth_state.dart';


class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;
  final TokenStorage _tokens;
  final FcmService _fcm;
  AuthNotifier({required AuthRepository repo, required TokenStorage tokens, required FcmService fcm})
      : _repo = repo, _tokens = tokens, _fcm = fcm, super(const AuthInitial()) { _resume(); }

  /// Called once from constructor. v3 pivot:
  ///   • no stored token → AuthAnonymous (browse freely, no login wall)
  ///   • stored token + /me works → AuthAuthenticated
  ///   • stored token but /me fails → tokens were stale → clear + AuthAnonymous
  ///
  /// v3.3 defense: an admin-role user must NEVER end up in the main app's auth state. The admin gate lives
  /// in its own parallel stack (AdminAuthNotifier + AdminTokenStorage); if we ever see an ADMIN user here
  /// it means something leaked an admin token into the main keystore — clear it and revert to anonymous so
  /// the main app stays clean. (This also self-heals leftover state from earlier builds that wrongly stored
  /// the admin JWT in the main TokenStorage.)
  Future<void> _resume() async {
    final access = await _tokens.readAccess();
    if (access == null) { state = const AuthAnonymous(); return; }
    try {
      final user = await _repo.fetchMe();
      if (user.role == UserRole.admin) {
        // Stale admin token leaked into the main keystore — wipe and stay anonymous.
        await _tokens.clear();
        state = const AuthAnonymous();
        return;
      }
      state = AuthAuthenticated(user);
      _registerPushQuietly();
    } on DioException catch (e) {
      // Only WIPE tokens on a definitive auth failure (401 / 403 after the api_client's refresh+replay
      // interceptor already gave up). Transient errors — network unreachable, 5xx server hiccup, DNS
      // failure during cold-start, request timeout, etc. — must NOT clear tokens, otherwise the user
      // gets kicked out by any flaky moment. Symptom: Device A appears to log itself out after a
      // network blip and the user blames Device B's sign-in. Token rotation already keeps refreshes
      // cheap, so leaving the bytes on disk costs nothing.
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        await _tokens.clear();
        state = const AuthAnonymous();
      } else {
        // Soft anonymous — keep tokens on disk so the next launch retries the resume. Don't clear.
        state = const AuthAnonymous();
      }
    } catch (_) {
      // Anything else (parse error, unexpected null) — log out the session but keep tokens; if the
      // failure is on our side a future build fixes it without forcing every existing user to re-login.
      state = const AuthAnonymous();
    }
  }

  /// Called from login screen submit — flips through Loading → Authenticated, or back to Unauthenticated(error)
  /// if the credentials were wrong (so the login screen can show the error inline).
  ///
  /// v3.3 defense: refuse to log an ADMIN-role user into the main app's session. Admin lives in its own
  /// auth context; if someone types admin@goshtli.local into the legacy email login form, we drop the
  /// tokens and pretend the credentials were wrong.
  Future<void> login(String email, String password) async {
    state = const AuthLoading();
    try {
      final user = await _repo.login(email: email, password: password);
      if (user.role == UserRole.admin) {
        await _repo.logout();
        state = const AuthUnauthenticated('Invalid credentials');
        return;
      }
      state = AuthAuthenticated(user);
      _registerPushQuietly();
    }
    on AuthException catch (e) { state = AuthUnauthenticated(e.message); }
  }

  /// Called from register screen — registers, then immediately logs in so the user lands on their dashboard without a second tap.
  Future<void> register({required String email, required String fullName, required String password,
                         required String phone, required UserRole role}) async {
    state = const AuthLoading();
    try {
      await _repo.register(email: email, fullName: fullName, password: password, phone: phone, role: role);
      state = AuthAuthenticated(await _repo.login(email: email, password: password));
      _registerPushQuietly();
    } on AuthException catch (e) { state = AuthUnauthenticated(e.message); }
  }

  /// Logout — clears tokens and drops back to anonymous. User keeps browsing without a forced login screen.
  /// FCM token stays on the device (Firebase persists per-install); next login re-registers it under the new user.
  Future<void> logout() async {
    await _repo.logout();
    state = const AuthAnonymous();
  }


  // ---------- Phone-based auth (v3.2) ----------

  /// Pure query — does NOT mutate auth state. PhoneEntryScreen calls this to decide whether to
  /// auto-login or push the details screen for registration. Throws AuthException on network/server errors
  /// so the screen can show an inline message.
  Future<bool> phoneCheck(String phone) => _repo.phoneCheck(phone);

  /// Passwordless phone login — used when phoneCheck returned true. Same state transitions as email login.
  ///
  /// v3.4 hardening: catches EVERY exception (not just AuthException). Anything that isn't AuthException
  /// (DioException, FormatException, network errors, …) used to leak through and leave the state stuck in
  /// AuthLoading — which made the Profile tab spin forever. Now we always exit Loading on the way out.
  Future<void> phoneLogin(String phone) async {
    state = const AuthLoading();
    try {
      state = AuthAuthenticated(await _repo.phoneLogin(phone));
      _registerPushQuietly();
    } on AuthException catch (e) { state = AuthUnauthenticated(e.message); }
    catch (e) { state = AuthUnauthenticated(e.toString()); }
  }

  /// Phone registration — creates the buyer account and logs them in in one shot. Called from the
  /// name-entry screen after phoneCheck returned false.
  Future<void> phoneRegister({required String phone, required String fullName, String businessName = ''}) async {
    state = const AuthLoading();
    try {
      state = AuthAuthenticated(await _repo.phoneRegister(
          phone: phone, fullName: fullName, businessName: businessName));
      _registerPushQuietly();
    } on AuthException catch (e) { state = AuthUnauthenticated(e.message); }
    catch (e) { state = AuthUnauthenticated(e.toString()); }
  }

  // NOTE: admin unlock is intentionally NOT here. The admin gate lives in its own parallel auth stack
  // (see features/admin/providers/admin_auth_*); it must not touch the main app's user session. Entering
  // /admin while logged in as a buyer keeps the buyer session intact; leaving /admin returns the user to
  // their previous state untouched.

  /// v3.9.16 Telegram phone-verification bridge. The code screen collected the 6-digit code the user got
  /// from the bot; we trade it (+ the start session token) for our JWT pair via /auth/telegram/verify/.
  /// Returns the repo's tri-state record so the screen knows whether to land on '/' (existing user) or push
  /// to '/auth/details' (new user) for name entry.
  ///
  /// Catches every exception (not just AuthException) so a DioException can't leave state stuck in
  /// AuthLoading (which would spin the Profile tab forever).
  Future<({User? user, bool isNew, String phone})> telegramVerify(String sessionToken, String code) async {
    state = const AuthLoading();
    try {
      final result = await _repo.telegramVerify(sessionToken, code);
      if (result.isNew) {
        // Hold in AuthAnonymous — not fully signed up until /auth/details + phoneRegister.
        state = const AuthAnonymous();
      } else {
        state = AuthAuthenticated(result.user!);
        _registerPushQuietly();
      }
      return result;
    } catch (e) {
      // Reset state on ANY failure so the app doesn't get stuck on a spinner. The caller (code screen)
      // shows its own error via on AuthException.
      state = const AuthAnonymous();
      rethrow;
    }
  }

  /// Hook called by ApiClient when a refresh attempt fails — keeps the auth state in sync without duplicating clear logic.
  void onAuthExpired() {
    if (state is AuthAuthenticated) state = const AuthUnauthenticated('Session expired');
  }

  /// Lets profile screens push a fresh User into state after PATCH /auth/me/ — avoids stale name/phone on the home screen.
  void updateUser(User user) { if (state is AuthAuthenticated) state = AuthAuthenticated(user); }

  /// Ask for notification permission then register the FCM token. Fire-and-forget — failures don't break auth.
  void _registerPushQuietly() async {
    try {
      await _fcm.requestPermission();
      await _fcm.registerCurrentToken();
    } catch (_) { /* push is best-effort; in-app notifications still work */ }
  }
}
