import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';

import '../config/env.dart';

/// Single TokenStorage across the partners app. Scoped with a `partner_` keystore prefix so a future
/// "have both apps installed at once" scenario doesn't collide.
final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage(keyPrefix: 'partner_'));

/// ApiClient — wired AFTER PartnerAuthNotifier exists so `onAuthExpired` can call into it.
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(tokens: ref.watch(tokenStorageProvider), baseUrl: Env.apiBaseUrl);
});

/// Firebase phone-auth bridge — used by the OTP screen to exchange Firebase ID token for backend JWT.
final firebaseBridgeProvider = Provider<FirebasePhoneBridge>((ref) => FirebasePhoneBridge(
      dio: ref.watch(apiClientProvider).dio,
      tokens: ref.watch(tokenStorageProvider),
    ));
