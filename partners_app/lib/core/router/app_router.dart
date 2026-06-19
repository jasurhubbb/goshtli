import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';

import '../../features/auth/otp_entry_screen.dart';
import '../../features/auth/phone_entry_screen.dart';
import '../../features/language/language_picker_screen.dart';
import '../../features/role_picker/role_picker_screen.dart';
import '../auth/partner_auth_notifier.dart';

/// Go-router for the partner app. Single root-level router (no shell yet — wizards push, then the
/// main 5-tab shell takes over after onboarding completes; Phase F adds the shell route).
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefreshNotifier(ref);
  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, gs) {
      final auth = ref.read(partnerAuthProvider);
      final loc = gs.matchedLocation;
      if (auth is AuthInitial || auth is AuthLoading) return null;
      // Authenticated → push past auth gates, but allow visits to home + nested routes.
      final loggedIn = auth is AuthAuthenticated;
      const authPaths = {'/auth/phone', '/auth/otp'};
      if (loggedIn && (loc == '/' || loc == '/role-pick' || authPaths.contains(loc))) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (ctx, st) => const LanguagePickerScreen()),
      GoRoute(path: '/role-pick', builder: (ctx, st) => const RolePickerScreen()),
      GoRoute(path: '/auth/phone', builder: (ctx, st) => const PhoneEntryScreen()),
      GoRoute(path: '/auth/otp', builder: (ctx, gs) {
        final extra = (gs.extra as Map<String, dynamic>?) ?? const {};
        return OtpEntryScreen(
          phone: extra['phone'] as String? ?? '',
          verificationId: extra['verificationId'] as String? ?? '',
        );
      }),
      // Onboarding wizards land here. Implementation in Phase E; this placeholder lets the project
      // compile in the meantime.
      GoRoute(path: '/onboarding', builder: (ctx, st) => const _OnboardingPlaceholder()),
      // Main 5-tab shell. Real implementation in Phase F.
      GoRoute(path: '/home', builder: (ctx, st) => const _HomePlaceholder()),
    ],
  );
});


/// Listens to the providers that affect redirect logic + bumps the router.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(partnerAuthProvider, (prev, next) => notifyListeners());
    ref.listen(localeNotifierProvider, (prev, next) => notifyListeners());
  }
}


class _OnboardingPlaceholder extends StatelessWidget {
  const _OnboardingPlaceholder();
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Text('Onboarding wizard — Phase E')),
  );
}


class _HomePlaceholder extends StatelessWidget {
  const _HomePlaceholder();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Partner Home')),
    body: const Center(child: Text('5-tab shell — Phase F')),
  );
}
