import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';

import '../network/providers.dart';

/// Partner-app auth. Same state shape as the buyer app, but owns the partner-specific resume +
/// post-login routing. SharedPreferences holds a `partner_role_draft` for the wizard flow.
class PartnerAuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _api;
  final TokenStorage _tokens;
  PartnerAuthNotifier({required ApiClient api, required TokenStorage tokens})
      : _api = api, _tokens = tokens, super(const AuthInitial()) { _resume(); }

  Future<void> _resume() async {
    final access = await _tokens.readAccess();
    if (access == null) { state = const AuthAnonymous(); return; }
    try {
      final r = await _api.dio.get('/auth/me/');
      if (r.statusCode == 200) {
        state = AuthAuthenticated(User.fromJson(r.data as Map<String, dynamic>));
      } else {
        state = const AuthAnonymous();
      }
    } on DioException catch (e) {
      // Only wipe tokens on confirmed 401/403; network blips leave them on disk for next launch.
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        await _tokens.clear();
      }
      state = const AuthAnonymous();
    } catch (_) {
      state = const AuthAnonymous();
    }
  }

  void setAuthenticated(User user) {
    state = AuthAuthenticated(user);
  }

  Future<void> logout() async {
    await _tokens.clear();
    state = const AuthAnonymous();
  }

  /// Hook called by ApiClient when refresh fails permanently.
  void onAuthExpired() {
    if (state is AuthAuthenticated) state = const AuthUnauthenticated('Session expired');
  }
}


final partnerAuthProvider = StateNotifierProvider<PartnerAuthNotifier, AuthState>((ref) {
  final notifier = PartnerAuthNotifier(
    api: ref.watch(apiClientProvider),
    tokens: ref.watch(tokenStorageProvider),
  );
  ref.read(apiClientProvider).onAuthExpired = notifier.onAuthExpired;
  return notifier;
});
