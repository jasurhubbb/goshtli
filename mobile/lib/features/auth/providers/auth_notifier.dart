// AuthNotifier — single source of truth for whether the user is logged in.
//
// v3 pivot: fresh installs and logout drop into AuthAnonymous (not AuthUnauthenticated). The app's home tab is
// reachable without a session; auth-required actions surface a sign-in sheet on demand.
//
// v2 Milestone E.5 hook: on successful login/register/resume we ask the OS for notification permission and
// register this device's FCM token with the backend so push events reach the right user.
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
    } catch (_) {
      await _tokens.clear();
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
  Future<void> phoneLogin(String phone) async {
    state = const AuthLoading();
    try {
      state = AuthAuthenticated(await _repo.phoneLogin(phone));
      _registerPushQuietly();
    } on AuthException catch (e) { state = AuthUnauthenticated(e.message); }
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
  }

  // NOTE: admin unlock is intentionally NOT here. The admin gate lives in its own parallel auth stack
  // (see features/admin/providers/admin_auth_*); it must not touch the main app's user session. Entering
  // /admin while logged in as a buyer keeps the buyer session intact; leaving /admin returns the user to
  // their previous state untouched.

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
