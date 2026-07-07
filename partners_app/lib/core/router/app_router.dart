import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';

import '../../features/auth/courier_login_screen.dart';
import '../../features/auth/otp_entry_screen.dart';
import '../../features/auth/phone_entry_screen.dart';
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
import '../../features/role_picker/role_picker_screen.dart';
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
      // Authenticated → push past auth gates, but allow visits to home + nested routes.
      final loggedIn = auth is AuthAuthenticated;
      const authPaths = {'/auth/phone', '/auth/otp'};
      if (loggedIn && (loc == '/' || loc == '/role-pick' || authPaths.contains(loc))) {
        return '/home';
      }
      // Anonymous on a protected path → bounce back to the role picker. Without this rule, tapping
      // Chiqish in Profil clears tokens but leaves the user stranded on /home/profile rendering an
      // empty user, and the next API call 401s into the void.
      const publicPaths = {'/', '/role-pick', '/auth/phone', '/auth/otp', '/onboarding',
                            '/auth/courier'};
      if (!loggedIn && !publicPaths.contains(loc)) {
        return '/role-pick';
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
      // v3.9.15 — dedicated courier email+password login. Distinct from the phone-OTP path because
      // courier accounts are admin-provisioned (no self-registration flow).
      GoRoute(path: '/auth/courier', builder: (ctx, st) => const CourierLoginScreen()),
      // Onboarding wizards — dispatched by role from roleDraftProvider. Qassob = 8 pages, Supplier = 7.
      GoRoute(path: '/onboarding', builder: (ctx, gs) {
        final extra = (gs.extra as Map<String, dynamic>?) ?? const {};
        final phone = extra['phone'] as String? ?? '';
        // We can't read providers here cleanly; route to a tiny dispatcher widget.
        return _WizardDispatcher(phone: phone);
      }),
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


/// Reads roleDraftProvider and dispatches to the right wizard.
class _WizardDispatcher extends ConsumerWidget {
  final String phone;
  const _WizardDispatcher({required this.phone});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(roleDraftProvider);
    if (role == UserRole.qassob) return QassobWizardScreen(phone: phone);
    if (role == UserRole.supplier) return SupplierWizardScreen(phone: phone);
    // Fallback — shouldn't happen since role-pick is a hard gate before phone/OTP, but a friendly UX
    // for ghost states.
    return Scaffold(
      appBar: AppBar(),
      body: const Center(child: Text('No role selected — please restart')),
    );
  }
}


