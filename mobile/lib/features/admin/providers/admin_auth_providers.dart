// Admin gate state — completely separate from the main app's AuthNotifier.
//
// State machine (kept tiny on purpose — admin doesn't need a full sealed hierarchy):
//   • locked:  no admin token cached (or just cleared); password prompt required to enter /admin
//   • unlocking: dialog is awaiting the admin-unlock response
//   • unlocked: valid admin token in AdminTokenStorage; /admin is accessible
//
// At app start we eagerly check for cached admin tokens — if present, we flip to unlocked without
// pinging the backend. The first admin API call validates the token; on 401 AdminApiClient calls
// onAdminAuthExpired which flips us back to locked.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_api_client.dart';
import '../data/admin_auth_repository.dart';
import '../data/admin_token_storage.dart';


enum AdminAuthStatus { locked, unlocking, unlocked }


class AdminAuthState {
  final AdminAuthStatus status;
  final String? error;                                     // populated only on the most recent failed unlock attempt
  const AdminAuthState(this.status, [this.error]);
  static const locked = AdminAuthState(AdminAuthStatus.locked);
  static const unlocking = AdminAuthState(AdminAuthStatus.unlocking);
  static const unlocked = AdminAuthState(AdminAuthStatus.unlocked);

  bool get isUnlocked => status == AdminAuthStatus.unlocked;
}


class AdminAuthNotifier extends StateNotifier<AdminAuthState> {
  final AdminAuthRepository _repo;
  final AdminTokenStorage _tokens;
  AdminAuthNotifier({required AdminAuthRepository repo, required AdminTokenStorage tokens})
      : _repo = repo, _tokens = tokens, super(AdminAuthState.locked) { _resume(); }

  /// On construction, eagerly check the admin keystore. If a token exists we go straight to unlocked —
  /// admin can re-enter /admin without re-prompting. Token validity is checked lazily on the first API call.
  Future<void> _resume() async {
    if (await _tokens.hasTokens()) state = AdminAuthState.unlocked;
  }

  /// Called from the Profile password dialog. Throws on failure so the dialog can render the message.
  Future<void> unlock(String password) async {
    state = AdminAuthState.unlocking;
    try {
      await _repo.unlock(password);
      state = AdminAuthState.unlocked;
    } on AdminAuthException catch (e) {
      state = AdminAuthState(AdminAuthStatus.locked, e.message);
      rethrow;
    }
  }

  /// Manual lock — called from the admin screen's "Chiqish" button. Clears admin tokens only; the main
  /// app's user session is untouched (still logged in as buyer, or still anonymous, whichever they were).
  Future<void> lock() async {
    await _repo.lock();
    state = AdminAuthState.locked;
  }

  /// Wired into AdminApiClient.onAdminAuthExpired (set up in admin_providers.dart). Fires when an admin
  /// API call returns 401 — the token's been revoked or expired. Flip to locked so the gate re-prompts.
  void onAdminAuthExpired() {
    if (state.status == AdminAuthStatus.unlocked) state = AdminAuthState.locked;
  }
}


// ---------- Providers ---------------------------------------------------------

final adminTokenStorageProvider = Provider<AdminTokenStorage>((ref) => AdminTokenStorage());

final adminApiClientProvider = Provider<AdminApiClient>(
    (ref) => AdminApiClient(tokens: ref.watch(adminTokenStorageProvider)));

final adminAuthRepositoryProvider = Provider<AdminAuthRepository>(
    (ref) => AdminAuthRepository(tokens: ref.watch(adminTokenStorageProvider)));

final adminAuthNotifierProvider = StateNotifierProvider<AdminAuthNotifier, AdminAuthState>((ref) {
  final notifier = AdminAuthNotifier(
    repo: ref.watch(adminAuthRepositoryProvider),
    tokens: ref.watch(adminTokenStorageProvider),
  );
  // Wire the 401 callback now that the notifier exists — same dance as the main ApiClient
  ref.read(adminApiClientProvider).onAdminAuthExpired = notifier.onAdminAuthExpired;
  return notifier;
});
