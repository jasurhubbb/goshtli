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
import '../../features/onboarding/presentation/supplier_wizard_screen.dart';
import '../../features/profile/qassob_profile_edit_screen.dart';
import '../../features/profile/supplier_profile_edit_screen.dart';
import '../../features/ratings/ratings_screen.dart';
import '../auth/partner_auth_notifier.dart';
import '../auth/role_draft_provider.dart';
import 'courier_shell.dart';
import 'partner_shell.dart';

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
      // v3.9.16 — partners no longer self-register. The only pre-auth screens are the language picker and
      // the phone+password login. After login the LoginScreen routes supplier/qassob into /onboarding
      // (the profile-setup wizard) or /home.
      final loggedIn = auth is AuthAuthenticated;
      // Authenticated → don't sit on the language / login screens; jump to home.
      if (loggedIn && (loc == '/' || loc == '/auth/login')) return '/home';
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
      // v3.9.16 — single credential login for all partner roles (supplier / qassob / courier).
      GoRoute(path: '/auth/login', builder: (ctx, st) => const LoginScreen()),
      // Profile-setup wizard — dispatched by role from roleDraftProvider (set by LoginScreen at login).
      // Reached post-login when a supplier/qassob account has no profile yet. Qassob = 8 pages, Supplier = 7.
      GoRoute(path: '/onboarding', builder: (ctx, gs) => const _WizardDispatcher()),
      // KYC upload — reachable from the verification banner + Profile tab.
      GoRoute(path: '/kyc', builder: (ctx, st) => const KycUploadScreen()),
      // Sharhlar (Reviews) — pushed from Profile tab. Empty state shows "no reviews yet" when partner
      // has none, instead of dead-tap behavior.
      GoRoute(path: '/ratings', builder: (ctx, st) => const RatingsScreen()),
      // Bildirishnomalar — partner's in-app FCM feed; on open we POST /notifications/read-all/ so the
      // bell badge resets.
      GoRoute(path: '/notifications', builder: (ctx, st) => const NotificationsScreen()),
      // Full-page Yangi tovar qo'shish — replaces the v3.8.1 sheet so the form has room to breathe +
      // can host an image picker. Pops with the new listing id so Katalog can refresh.
      GoRoute(path: '/catalog/new', builder: (ctx, st) => const NewListingScreen()),
      // v3.9.13 — supplier product detail (photo + info rows + Delete button with active-order
      // guard). Pops with `true` when the delete succeeds so the Katalog list refreshes.
      GoRoute(path: '/catalog/:id',
          builder: (ctx, gs) => ListingDetailScreen(
              listingId: int.parse(gs.pathParameters['id']!))),
      // v3.9.8 — dedicated full-page qassob profile edit screen (avatar upload + name + phone
      // visibility). Replaces the previous one-size-fits-all sheet for qassobs because they need
      // a proper photo editor that doesn't fit in a bottom sheet.
      GoRoute(path: '/profile/edit-qassob',
          builder: (ctx, st) => const QassobProfileEditScreen()),
      // v3.9.12 — same treatment for suppliers. Bottom sheet couldn't fit the avatar editor + name
      // + business_name + phone toggle without feeling cramped; dedicated page mirrors the qassob
      // one so both partner roles get the same production-quality profile-edit surface.
      GoRoute(path: '/profile/edit-supplier',
          builder: (ctx, st) => const SupplierProfileEditScreen()),
      // v3.9 — chat list + chat detail. Reachable from the dashboard chat icon and from push
      // notification deep links. Detail screen owns the WebSocket lifecycle.
      GoRoute(path: '/chats', builder: (ctx, st) => const PartnerChatsListScreen()),
      GoRoute(path: '/chats/:id',
          builder: (ctx, gs) => PartnerChatDetailScreen(
              conversationId: int.parse(gs.pathParameters['id']!))),
      // v3.9.15 — courier delivery detail. Pushed from Queue / Active / History rows in CourierShell.
      // Owns the state-advance buttons, cash input, and photo-proof upload for one delivery.
      GoRoute(path: '/courier/delivery/:id',
          builder: (ctx, gs) => CourierDeliveryDetailScreen(
              deliveryId: int.parse(gs.pathParameters['id']!))),
      // Main 5-tab shell — role-branched. Couriers get their delivery-driver shell (Queue / Active
      // / Earnings / History / Profile); everyone else (qassob + supplier) gets the standard
      // PartnerShell. Consumer wrapper reads the auth state so the choice re-evaluates when the
      // user completes login.
      GoRoute(path: '/home', builder: (ctx, st) => Consumer(builder: (_, ref, __) {
        final auth = ref.watch(partnerAuthProvider);
        final isCourier = auth is AuthAuthenticated && auth.user.isCourier;
        return isCourier ? const CourierShell() : const PartnerShell();
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


/// Reads roleDraftProvider (set by LoginScreen from the account's role) and dispatches to the right wizard.
class _WizardDispatcher extends ConsumerWidget {
  const _WizardDispatcher();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(roleDraftProvider);
    if (role == UserRole.qassob) return const QassobWizardScreen();
    if (role == UserRole.supplier) return const SupplierWizardScreen();
    // Fallback — role draft should be set at login; friendly UX for ghost states.
    return Scaffold(
      appBar: AppBar(),
      body: const Center(child: Text('No role selected — please restart')),
    );
  }
}


