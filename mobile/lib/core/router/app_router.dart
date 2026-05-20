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

import '../../features/auth/presentation/login_screen.dart';
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

      // v3 pivot: no blanket auth wall. Anonymous can browse the app. Specific auth-required SCREENS guard themselves:
      //   • /login or /register — accessible from anywhere; if already logged in, send home
      //   • Everything else allowed for anonymous + authenticated alike
      final loggedIn = auth is AuthAuthenticated;
      final atAuth = loc == '/login' || loc == '/register';
      if (loggedIn && atAuth) return '/';
      return null;
    },
    routes: [
      // ---------- Onboarding (no shell, no auth required) ----------
      GoRoute(path: '/onboarding', name: 'onboarding', builder: (_, _) => const OnboardingScreen()),

      // ---------- Auth (no shell) ----------
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
