// Riverpod providers wiring TokenStorage → ApiClient → AuthRepository → AuthNotifier (+ FcmService).
//
// ApiClient.onAuthExpired is wired AFTER the AuthNotifier exists (inside authNotifierProvider's body) — this breaks
// the otherwise cyclic dependency between ApiClient and AuthNotifier without requiring a stream/event-bus indirection.
//
// FcmService is injected into AuthNotifier so login/register/_resume can register the device's FCM token.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/token_storage.dart';
import '../../../core/network/api_client.dart';
import '../../../core/push/fcm_service.dart';
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


/// FcmService — shares the same ApiClient so the register-device call rides the same auth interceptor as everything else.
///
/// v3.9.12 — passes `ref` in so the FCM service can invalidate other providers when a foreground
/// push arrives (live-refresh of Buyurtmalar list, chat unread badge, conversations).
final fcmServiceProvider = Provider<FcmService>((ref) =>
    FcmService(ref.watch(apiClientProvider), ref: ref));


/// The screen-facing notifier. Reads use ref.watch(authNotifierProvider); mutations use ref.read(authNotifierProvider.notifier).
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final notifier = AuthNotifier(
      repo: ref.watch(authRepositoryProvider),
      tokens: ref.watch(tokenStorageProvider),
      fcm: ref.watch(fcmServiceProvider));
  // Wire the refresh-failure hook into ApiClient now that the notifier instance exists — no static cycle, no runtime race
  ref.read(apiClientProvider).onAuthExpired = notifier.onAuthExpired;
  return notifier;
});
