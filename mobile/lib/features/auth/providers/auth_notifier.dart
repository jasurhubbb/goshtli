// AuthNotifier — single source of truth for whether the user is logged in. Routing + role gates read this.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/token_storage.dart';
import '../../../shared/models/user.dart';
import '../data/auth_repository.dart';
import 'auth_state.dart';


class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;
  final TokenStorage _tokens;
  AuthNotifier({required AuthRepository repo, required TokenStorage tokens})
      : _repo = repo, _tokens = tokens, super(const AuthInitial()) { _resume(); }

  /// Called once from constructor — if we have a stored token, try /me and resume the session; otherwise sit at Unauthenticated.
  Future<void> _resume() async {
    final access = await _tokens.readAccess();
    if (access == null) { state = const AuthUnauthenticated(); return; }
    try {
      final user = await _repo.fetchMe();
      state = AuthAuthenticated(user);
    } catch (_) {
      // /me failed even after the auto-refresh interceptor tried — token is dead, force re-login
      await _tokens.clear();
      state = const AuthUnauthenticated();
    }
  }

  /// Called from login screen submit — flips through Loading→Authenticated or Loading→Unauthenticated(error).
  Future<void> login(String email, String password) async {
    state = const AuthLoading();
    try { state = AuthAuthenticated(await _repo.login(email: email, password: password)); }
    on AuthException catch (e) { state = AuthUnauthenticated(e.message); }
  }

  /// Called from register screen — registers, then immediately logs in so the user lands on their dashboard without a second tap.
  Future<void> register({required String email, required String fullName, required String password,
                         required String phone, required UserRole role}) async {
    state = const AuthLoading();
    try {
      await _repo.register(email: email, fullName: fullName, password: password, phone: phone, role: role);
      state = AuthAuthenticated(await _repo.login(email: email, password: password));
    } on AuthException catch (e) { state = AuthUnauthenticated(e.message); }
  }

  /// Logout — clears tokens and flips state. Triggers go_router redirect back to /login via the authProvider listen.
  Future<void> logout() async {
    await _repo.logout();
    state = const AuthUnauthenticated();
  }

  /// Hook called by ApiClient when a refresh attempt fails — keeps the auth state in sync without duplicating clear logic.
  void onAuthExpired() {
    if (state is AuthAuthenticated) state = const AuthUnauthenticated('Session expired');
  }

  /// Lets profile screens push a fresh User into state after PATCH /auth/me/ — avoids stale name/phone on the home screen.
  void updateUser(User user) { if (state is AuthAuthenticated) state = AuthAuthenticated(user); }
}
