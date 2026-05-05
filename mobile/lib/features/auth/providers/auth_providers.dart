// Riverpod providers wiring TokenStorage → ApiClient → AuthRepository → AuthNotifier.
//
// ApiClient.onAuthExpired is wired AFTER the AuthNotifier exists (inside authNotifierProvider's body) — this breaks the otherwise
// cyclic dependency between ApiClient and AuthNotifier without requiring a stream/event-bus indirection.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/token_storage.dart';
import '../../../core/network/api_client.dart';
import '../data/auth_repository.dart';
import 'auth_notifier.dart';
import 'auth_state.dart';


/// Single TokenStorage — held alive for app lifetime since flutter_secure_storage init is mildly expensive.
final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());


/// ApiClient — created without the auth-expired callback; auth_providers wires it up post-construction.
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(tokens: ref.watch(tokenStorageProvider)));


/// AuthRepository — pure HTTP layer with no UI concerns.
final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(
      api: ref.watch(apiClientProvider), tokens: ref.watch(tokenStorageProvider),
    ));


/// The screen-facing notifier. Reads use ref.watch(authNotifierProvider); mutations use ref.read(authNotifierProvider.notifier).
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final notifier = AuthNotifier(repo: ref.watch(authRepositoryProvider), tokens: ref.watch(tokenStorageProvider));
  // Wire the refresh-failure hook into ApiClient now that the notifier instance exists — no static cycle, no runtime race
  ref.read(apiClientProvider).onAuthExpired = notifier.onAuthExpired;
  return notifier;
});
