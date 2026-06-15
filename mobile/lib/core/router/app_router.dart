// Centralized go_router config — 5-tab shell with lazy auth (v3 pivot).
//
// Routing rules:
//   • AuthInitial → splash spinner (waiting for SharedPreferences + token check)
//   • Fresh install + onboarding not done → /onboarding (location prompt)
//   • Anonymous user → can hit /, /search, /listings/:id, /chats/:id (the chat screen will gate itself).
//     The Profile tab handles its own anonymous CTA. Chat/Notifications tabs land on a "sign in" prompt.
//   • Authenticated → no extra redirects; can also visit /login or /register without being bounced (e.g. switching account)
//
// Detail screens (listing, order, create-listing) are TOP-LEVEL routes that push above the tab bar.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/addresses/presentation/address_form_screen.dart';
import '../../features/addresses/presentation/address_map_screen.dart';
import '../../features/admin/presentation/admin_listing_edit_screen.dart';
import '../../features/admin/presentation/admin_manage_section_screen.dart';
import '../../features/admin/presentation/admin_market_detail_screen.dart';
import '../../features/admin/presentation/admin_screen.dart';
import '../../features/admin/providers/admin_auth_providers.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/otp_entry_screen.dart';
import '../../features/auth/presentation/phone_details_screen.dart';
import '../../features/auth/presentation/phone_entry_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/auth/providers/auth_state.dart';
import '../../features/cart/presentation/cart_screen.dart';
import '../../features/chats/presentation/chat_detail_screen.dart';
import '../../features/chats/presentation/chats_screen.dart';
import '../../features/favorites/presentation/favorites_screen.dart';
import '../../features/dashboard/presentation/home_screen.dart';
import '../../features/listings/presentation/listing_create_screen.dart';
import '../../features/listings/presentation/listing_detail_screen.dart';
import '../../features/listings/presentation/listings_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/delivery/presentation/delivery_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/orders/presentation/order_detail_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/payments/presentation/my_cards_screen.dart';
import '../../features/payments/presentation/order_pay_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/profile_settings_screen.dart';
import '../location/location_providers.dart';
import 'main_shell.dart';


/// Splash shown during AuthInitial — prevents UI flicker on cold start while we read tokens + onboarding flag.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}


/// Listens to the auth-affecting Riverpod providers and signals GoRouter to re-evaluate redirects WITHOUT
/// rebuilding the router itself. This is the go_router-recommended Riverpod-integration pattern.
///
/// Why this exists: the previous version did `ref.watch(authNotifierProvider)` inside `Provider<GoRouter>`,
/// which made the Provider rebuild on every auth change. A new GoRouter instance → MaterialApp.router
/// detects a different `routerConfig` → tears down + rebuilds the entire navigation tree → screens
/// mid-await (e.g. OtpEntryScreen calling `firebasePhoneLogin`) end up navigating from a deactivated
/// element and `context.go(...)` throws "Looking up a deactivated widget's ancestor is unsafe".
///
/// With this notifier, the GoRouter instance stays the same forever; only its redirect logic re-runs
/// when auth state changes, so the widget tree never gets torn down.
class _GoRouterRefreshNotifier extends ChangeNotifier {
  _GoRouterRefreshNotifier(Ref ref) {
    ref.listen(authNotifierProvider, (_, _) => notifyListeners());
    ref.listen(adminAuthNotifierProvider, (_, _) => notifyListeners());
    ref.listen(onboardingDoneProvider, (_, _) => notifyListeners());
  }
}


final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _GoRouterRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/',
    // refreshListenable triggers redirect re-evaluation without re-creating the GoRouter
    refreshListenable: refresh,
    redirect: (context, gstate) {
      // ref.read (not watch) — we want the current snapshot at redirect-time; the listenable above is
      // what makes go_router re-run this callback when these providers change.
      final auth = ref.read(authNotifierProvider);
      final adminAuth = ref.read(adminAuthNotifierProvider);
      final onboardingDone = ref.read(onboardingDoneProvider).asData?.value;
      final loc = gstate.matchedLocation;

      // While loading, don't redirect — splash route handles the spinner
      if (auth is AuthInitial || auth is AuthLoading || onboardingDone == null) return null;

      // First-run gate — onboarding (location prompt) must complete before app is usable
      if (!onboardingDone && loc != '/onboarding') return '/onboarding';
      if (onboardingDone && loc == '/onboarding') return '/';

      // v3 pivot: no blanket auth wall. Anonymous can browse the app. Specific auth-required SCREENS guard themselves.
      final loggedIn = auth is AuthAuthenticated;
      if (!loggedIn && (loc == '/login' || loc == '/register')) return '/auth/phone';
      // /auth/otp is in this list so existing-user Firebase logins (which silently flip the state to
      // AuthAuthenticated without navigating) auto-redirect to home instead of leaving the user staring
      // at the OTP screen they just succeeded on.
      final atAuth = loc == '/login' || loc == '/register'
          || loc == '/auth/phone' || loc == '/auth/otp' || loc == '/auth/details';
      if (loggedIn && atAuth) return '/';

      // v3.3: admin routes are gated on the SEPARATE admin auth (AdminAuthNotifier). If admin lock state is
      // not unlocked and the user lands on /admin/*, bounce to /profile so they re-enter the password.
      if (loc.startsWith('/admin') && !adminAuth.isUnlocked) return '/profile';
      return null;
    },
    routes: [
      // ---------- Onboarding (no shell, no auth required) ----------
      GoRoute(path: '/onboarding', name: 'onboarding', builder: (_, _) => const OnboardingScreen()),

      // ---------- Auth (no shell) ----------
      // v3.2 phone-based flow — the primary mobile auth path. PhoneEntryScreen branches on phone-check, then
      // pushes /auth/details with the phone in `extra` if it's a new account.
      GoRoute(path: '/auth/phone', name: 'auth-phone', builder: (_, _) => const PhoneEntryScreen()),
      GoRoute(path: '/auth/otp', name: 'auth-otp',
        // OTP screen needs the phone (display) and Firebase's verificationId (opaque session id) — both
        // passed via go_router `extra`. Direct deep-links without that payload bounce back to /auth/phone.
        redirect: (_, gs) {
          final extra = gs.extra as Map<String, dynamic>?;
          final hasPayload = extra != null && extra['phone'] is String && extra['verificationId'] is String;
          return hasPayload ? null : '/auth/phone';
        },
        builder: (_, gs) {
          final extra = gs.extra as Map<String, dynamic>;
          return OtpEntryScreen(
            phone: extra['phone'] as String,
            initialVerificationId: extra['verificationId'] as String,
          );
        }),
      GoRoute(path: '/auth/details', name: 'auth-details',
        redirect: (_, gs) {
          // Deep-links to /auth/details without `extra` carrying the phone are nonsense — bounce them to /auth/phone
          // so the flow starts at step 1. Legitimate entry always carries extra={'phone': '+998XXXXXXXXX'}.
          final phone = (gs.extra as Map<String, dynamic>?)?['phone'] as String?;
          return (phone == null || phone.isEmpty) ? '/auth/phone' : null;
        },
        builder: (_, gs) {
          final phone = (gs.extra as Map<String, dynamic>?)?['phone'] as String;
          return PhoneDetailsScreen(phone: phone);
        }),
      // Legacy email-password screens — kept for now (redirect above sends anonymous traffic to /auth/phone).
      GoRoute(path: '/login', name: 'login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', name: 'register', builder: (_, _) => const RegisterScreen()),

      // ---------- Full-screen detail/create routes (push above the tab bar) ----------
      GoRoute(path: '/listings/new', name: 'listing-new', builder: (_, _) => const ListingCreateScreen()),
      GoRoute(path: '/listings/:id', name: 'listing-detail',
        builder: (_, gs) => ListingDetailScreen(listingId: int.parse(gs.pathParameters['id']!))),
      GoRoute(path: '/orders/:id', name: 'order-detail',
        builder: (_, gs) => OrderDetailScreen(orderId: int.parse(gs.pathParameters['id']!))),
      // v3.5 — WebView checkout. Reachable from the cart "Buyurtma berish" CTA right after the order is
      // created, OR from the order detail screen's "To'lash" button on unpaid orders.
      GoRoute(path: '/orders/:id/pay', name: 'order-pay',
        builder: (_, gs) => OrderPayScreen(orderId: int.parse(gs.pathParameters['id']!))),
      // v3.6 PRD §3 — separate delivery page between Cart and Payment. Buyer picks vehicle + time slot,
      // optionally requests butcher service, sees the price breakdown, then proceeds to pay.
      GoRoute(path: '/delivery', name: 'delivery',
        builder: (_, _) => const DeliveryScreen()),
      // v3.7 — "Mening kartalarim". Reachable from Profile + as a return target after AddCardSheet.
      GoRoute(path: '/profile/cards', name: 'my-cards',
        builder: (_, _) => const MyCardsScreen()),
      GoRoute(path: '/chats/:id', name: 'chat-detail',
        builder: (_, gs) => ChatDetailScreen(conversationId: int.parse(gs.pathParameters['id']!))),
      GoRoute(path: '/profile/saved', name: 'favorites', builder: (_, _) => const FavoritesScreen()),

      // ---------- Admin (v3.3) ----------
      // Soft-gated by a password prompt on the Profile screen; backend permissions still enforce ADMIN role on
      // every mutation. Sub-section routes (Listings/Suppliers/Categories/Markets) push above /admin so back
      // returns to the tab bar.
      GoRoute(path: '/admin', name: 'admin', builder: (_, _) => const AdminScreen()),
      GoRoute(path: '/admin/markets/:id', name: 'admin-market-detail',
        builder: (_, gs) => AdminMarketDetailScreen(
            marketId: int.parse(gs.pathParameters['id']!))),
      GoRoute(path: '/admin/listings/:id', name: 'admin-listing-edit',
        builder: (_, gs) => AdminListingEditScreen(
            listingId: int.parse(gs.pathParameters['id']!))),
      GoRoute(path: '/admin/manage/:section', name: 'admin-manage-section',
        builder: (_, gs) {
          final raw = gs.pathParameters['section'] ?? '';
          // Resolve the enum from the path param; default to Listings on any unknown value so we never crash on
          // a malformed deep link.
          final section = AdminSection.values.firstWhere((e) => e.name == raw,
              orElse: () => AdminSection.listings);
          return AdminManageSectionScreen(section: section);
        }),

      // v3.3 — editable buyer details (Familiya / Ism / Otasining ismi / DOB / Jins). Pushes above the tab bar
      // so a back arrow returns to the Profile tab with the latest hero values refreshed.
      GoRoute(path: '/profile/settings', name: 'profile-settings',
        builder: (_, _) => const ProfileSettingsScreen()),

      // ---------- Address management (v3.1) ----------
      // /addresses/new   → create form
      // /addresses/<id>  → edit form (loads from addressesProvider's cached list)
      // /addresses/map   → OSM map picker, popped with {lat, lng, displayName} payload
      GoRoute(path: '/addresses/new', name: 'address-new',
        builder: (_, gs) {
          // When this route is reached via the map → pushReplacement flow, the picked coordinates + display
          // name + house number (if Nominatim resolved one) come in via `extra`. Otherwise opens blank.
          final extra = gs.extra as Map<String, dynamic>? ?? const {};
          return AddressFormScreen(
            prefilledLat: extra['lat'] as double?,
            prefilledLng: extra['lng'] as double?,
            prefilledDisplayName: extra['displayName'] as String?,
            prefilledHouseNumber: extra['houseNumber'] as String?);
        }),
      GoRoute(path: '/addresses/map', name: 'address-map',
        builder: (_, gs) {
          final extra = gs.extra as Map<String, dynamic>? ?? const {};
          return AddressMapScreen(
            initialLat: extra['initialLat'] as double?,
            initialLng: extra['initialLng'] as double?,
            initialQuery: extra['initialQuery'] as String?);
        }),
      GoRoute(path: '/addresses/:id', name: 'address-edit',
        builder: (_, gs) => AddressFormScreen(addressId: int.parse(gs.pathParameters['id']!))),

      // ---------- Top-level routes for screens that left the bottom bar (kept for deep-links + nested nav) ----------
      GoRoute(path: '/search', name: 'search', builder: (_, _) => const ListingsScreen()),
      GoRoute(path: '/notifications', name: 'notifications', builder: (_, _) => const NotificationsScreen()),
      GoRoute(path: '/chats', name: 'chats', builder: (_, _) => const ChatsScreen()),

      // ---------- 4-tab shell (Menyu / Savat / Buyurtmalar / Profil) ----------
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainShell(navigationShell: navigationShell),
        branches: [
          // 0 — Menyu (home product grid)
          StatefulShellBranch(routes: [
            // Splash while auth resumes from secure storage; otherwise the real home grid. Reading auth via
            // a small Consumer keeps this route immune to the "rebuild the whole router" trap — only this
            // sub-widget reacts to auth changes, not the entire MaterialApp.router.
            GoRoute(path: '/', name: 'home',
              builder: (_, _) => Consumer(builder: (_, cref, _) =>
                cref.watch(authNotifierProvider) is AuthInitial
                    ? const _SplashScreen() : const HomeScreen())),
          ]),
          // 1 — Savat (cart)
          StatefulShellBranch(routes: [
            GoRoute(path: '/savat', name: 'cart', builder: (_, _) => const CartScreen()),
          ]),
          // 2 — Buyurtmalar (orders)
          StatefulShellBranch(routes: [
            GoRoute(path: '/orders', name: 'orders', builder: (_, _) => const OrdersScreen()),
          ]),
          // 3 — Profil
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', name: 'profile', builder: (_, _) => const ProfileScreen(),
              routes: [
                // Nested route preserved — Saved listings opens from the authenticated profile shortcut
                GoRoute(path: 'orders', name: 'profile-orders', builder: (_, _) => const OrdersScreen()),
                GoRoute(path: 'listings', name: 'profile-listings', builder: (_, _) => const ListingsScreen()),
              ]),
          ]),
        ],
      ),
    ],
  );
});
