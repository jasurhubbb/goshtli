import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';

import '../../features/auth/login_screen.dart';
import '../../features/catalog/listing_detail_screen.dart';
import '../../features/catalog/new_listing_screen.dart';
import '../../features/chats/chat_detail_screen.dart';
import '../../features/chats/chats_list_screen.dart';
import '../../features/courier/presentation/courier_delivery_detail_screen.dart';
import '../../features/kyc/kyc_upload_screen.dart';
import '../../features/language/language_picker_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/onboarding/presentation/qassob_wizard_screen.dart';
import '../../features/profile/qassob_profile_edit_screen.dart';
import '../../features/ratings/ratings_screen.dart';
import '../auth/partner_auth_notifier.dart';
import '../auth/role_draft_provider.dart';
import 'courier_shell.dart';
import 'internal_catalog_shell.dart';
import 'partner_shell.dart';
import 'workspace_kind.dart';

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
      // Accounts are issued by the platform. Internal catalog operators go straight to their
      // workspace; only qassobs can be sent through profile onboarding.
      final loggedIn = auth is AuthAuthenticated;
      // Authenticated → don't sit on the language / login screens; jump to home.
      if (loggedIn && (loc == '/' || loc == '/auth/login')) return '/home';
      if (loggedIn && loc == '/onboarding' && auth.user.isCatalogOperator) {
        return '/home';
      }
      // Anonymous on a protected path → bounce to login. Without this, tapping Chiqish in Profil clears
      // tokens but leaves the user stranded on /home/profile with the next API call 401-ing into the void.
      const publicPaths = {'/', '/auth/login'};
      if (!loggedIn && !publicPaths.contains(loc)) {
        return '/auth/login';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (ctx, st) => const LanguagePickerScreen()),
      // Single credential login for internal catalog operators, qassobs, and couriers.
      GoRoute(path: '/auth/login', builder: (ctx, st) => const LoginScreen()),
      // Profile setup is now qassob-only. Catalog operators are platform staff and never onboard
      // as public suppliers.
      GoRoute(
          path: '/onboarding', builder: (ctx, gs) => const _WizardDispatcher()),
      // KYC upload — reachable from the verification banner + Profile tab.
      GoRoute(path: '/kyc', builder: (ctx, st) => const KycUploadScreen()),
      // Sharhlar (Reviews) — pushed from Profile tab. Empty state shows "no reviews yet" when partner
      // has none, instead of dead-tap behavior.
      GoRoute(path: '/ratings', builder: (ctx, st) => const RatingsScreen()),
      // Bildirishnomalar — partner's in-app FCM feed; on open we POST /notifications/read-all/ so the
      // bell badge resets.
      GoRoute(
          path: '/notifications',
          builder: (ctx, st) => const NotificationsScreen()),
      // Full-page Yangi tovar qo'shish — replaces the v3.8.1 sheet so the form has room to breathe +
      // can host an image picker. Pops with the new listing id so Katalog can refresh.
      GoRoute(
          path: '/catalog/new', builder: (ctx, st) => const NewListingScreen()),
      // Internal listing detail and management actions.
      GoRoute(
          path: '/catalog/:id',
          builder: (ctx, gs) => ListingDetailScreen(
              listingId: int.parse(gs.pathParameters['id']!))),
      // v3.9.8 — dedicated full-page qassob profile edit screen (avatar upload + name + phone
      // visibility). Replaces the previous one-size-fits-all sheet for qassobs because they need
      // a proper photo editor that doesn't fit in a bottom sheet.
      GoRoute(
          path: '/profile/edit-qassob',
          builder: (ctx, st) => const QassobProfileEditScreen()),
      // v3.9 — chat list + chat detail. Reachable from the dashboard chat icon and from push
      // notification deep links. Detail screen owns the WebSocket lifecycle.
      GoRoute(
          path: '/chats', builder: (ctx, st) => const PartnerChatsListScreen()),
      GoRoute(
          path: '/chats/:id',
          builder: (ctx, gs) => PartnerChatDetailScreen(
              conversationId: int.parse(gs.pathParameters['id']!))),
      // v3.9.15 — courier delivery detail. Pushed from Queue / Active / History rows in CourierShell.
      // Owns the state-advance buttons, cash input, and photo-proof upload for one delivery.
      GoRoute(
          path: '/courier/delivery/:id',
          builder: (ctx, gs) => CourierDeliveryDetailScreen(
              deliveryId: int.parse(gs.pathParameters['id']!))),
      // Role-branched workspace. The backend's SUPPLIER role is intentionally retained as the
      // compatibility identity for the platform's internal catalog operator, but the UI never
      // presents that account as an external seller.
      GoRoute(
          path: '/home',
          builder: (ctx, st) => Consumer(builder: (_, ref, __) {
                final auth = ref.watch(partnerAuthProvider);
                if (auth is! AuthAuthenticated) return const SizedBox.shrink();
                return switch (workspaceKindForRole(auth.user.role)) {
                  PartnerWorkspaceKind.internalCatalog =>
                    const InternalCatalogShell(),
                  PartnerWorkspaceKind.qassob => const PartnerShell(),
                  PartnerWorkspaceKind.courier => const CourierShell(),
                  PartnerWorkspaceKind.unsupported =>
                    const _UnsupportedRoleScreen(),
                };
              })),
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

/// The only remaining self-service onboarding flow belongs to qassobs.
class _WizardDispatcher extends ConsumerWidget {
  const _WizardDispatcher();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(roleDraftProvider);
    if (role == UserRole.qassob) return const QassobWizardScreen();
    return Scaffold(
      appBar: AppBar(),
      body: const Center(
          child: Text('Onboarding is available for qassobs only.')),
    );
  }
}

class _UnsupportedRoleScreen extends ConsumerWidget {
  const _UnsupportedRoleScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text("Go'sht Bozori")),
        body: Center(
            child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_person_outlined, size: 52),
            const SizedBox(height: 16),
            const Text('This account does not have access to the working app.',
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => ref.read(partnerAuthProvider.notifier).logout(),
              child: const Text('Log out'),
            ),
          ]),
        )),
      );
}
