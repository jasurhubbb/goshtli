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
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/orders/presentation/order_detail_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
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


final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authNotifierProvider);
  final adminAuth = ref.watch(adminAuthNotifierProvider);
  final onboardingDone = ref.watch(onboardingDoneProvider).asData?.value;

  return GoRouter(
    initialLocation: '/',
    redirect: (context, gstate) {
      final loc = gstate.matchedLocation;

      // While loading, don't redirect — splash route handles the spinner
      if (auth is AuthInitial || auth is AuthLoading || onboardingDone == null) return null;

      // First-run gate — onboarding (location prompt) must complete before app is usable
      if (!onboardingDone && loc != '/onboarding') return '/onboarding';
      if (onboardingDone && loc == '/onboarding') return '/';

      // v3 pivot: no blanket auth wall. Anonymous can browse the app. Specific auth-required SCREENS guard themselves.
      // v3.2: phone-based auth is the primary mobile flow — the legacy /login + /register routes redirect to /auth/phone
      // so existing links keep working while we phase the email-password screens out.
      final loggedIn = auth is AuthAuthenticated;
      if (!loggedIn && (loc == '/login' || loc == '/register')) return '/auth/phone';
      final atAuth = loc == '/login' || loc == '/register' || loc == '/auth/phone' || loc == '/auth/details';
      if (loggedIn && atAuth) return '/';

      // v3.3: admin routes are gated on the SEPARATE admin auth (AdminAuthNotifier). If admin lock state is
      // not unlocked and the user lands on /admin/*, bounce to /profile so they re-enter the password.
      // This is independent of the user's main-app session — buyer-logged-in users can be admin-locked.
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
            GoRoute(path: '/', name: 'home',
              builder: (_, _) => auth is AuthInitial ? const _SplashScreen() : const HomeScreen()),
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
