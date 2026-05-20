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
  Future<void> _resume() async {
    final access = await _tokens.readAccess();
    if (access == null) { state = const AuthAnonymous(); return; }
    try {
      final user = await _repo.fetchMe();
      state = AuthAuthenticated(user);
      _registerPushQuietly();
    } catch (_) {
      await _tokens.clear();
      state = const AuthAnonymous();
    }
  }

  /// Called from login screen submit — flips through Loading → Authenticated, or back to Unauthenticated(error)
  /// if the credentials were wrong (so the login screen can show the error inline).
  Future<void> login(String email, String password) async {
    state = const AuthLoading();
    try {
      state = AuthAuthenticated(await _repo.login(email: email, password: password));
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
