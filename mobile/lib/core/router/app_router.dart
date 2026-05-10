// Centralized go_router config — auth-gated 5-tab shell. Each tab is its own StatefulShellBranch so back-stack
// state (scroll, sub-routes) is preserved across tab switches.
//
// Routing rules:
//   • AuthInitial / AuthLoading → no redirect; splash shows a spinner
//   • AuthUnauthenticated → force /login if not already on auth screens
//   • AuthAuthenticated → bounce off /login & /register back to home
//
// Detail screens (listing, order, create-listing) are TOP-LEVEL routes that push above the tab bar — matches
// Karrot/OLX/iOS conventions: opening an item is a modal-style focused task, not a tab-internal navigation.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/auth/providers/auth_state.dart';
import '../../features/chats/presentation/chat_detail_screen.dart';
import '../../features/chats/presentation/chats_screen.dart';
import '../../features/favorites/presentation/favorites_screen.dart';
import '../../features/dashboard/presentation/home_screen.dart';
import '../../features/listings/presentation/listing_create_screen.dart';
import '../../features/listings/presentation/listing_detail_screen.dart';
import '../../features/listings/presentation/listings_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/orders/presentation/order_detail_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import 'main_shell.dart';


/// Splash shown during AuthInitial — prevents login flicker before /me resolves on cold start.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}


final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authNotifierProvider);
  return GoRouter(
    initialLocation: '/',
    redirect: (context, gstate) {
      final loc = gstate.matchedLocation;
      if (auth is AuthInitial || auth is AuthLoading) return null;
      final loggedIn = auth is AuthAuthenticated;
      final atAuth = loc == '/login' || loc == '/register';
      if (!loggedIn && !atAuth) return '/login';
      if (loggedIn && atAuth) return '/';
      return null;
    },
    routes: [
      // ---------- Auth (no shell) ----------
      GoRoute(path: '/login', name: 'login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', name: 'register', builder: (_, _) => const RegisterScreen()),

      // ---------- Full-screen detail/create routes (push above the tab bar) ----------
      GoRoute(path: '/listings/new', name: 'listing-new', builder: (_, _) => const ListingCreateScreen()),
      GoRoute(path: '/listings/:id', name: 'listing-detail',
        builder: (_, gs) => ListingDetailScreen(listingId: int.parse(gs.pathParameters['id']!))),
      GoRoute(path: '/orders/:id', name: 'order-detail',
        builder: (_, gs) => OrderDetailScreen(orderId: int.parse(gs.pathParameters['id']!))),
      // v2 Milestone C — chat detail + saved listings push above the tabs (focused screens)
      GoRoute(path: '/chats/:id', name: 'chat-detail',
        builder: (_, gs) => ChatDetailScreen(conversationId: int.parse(gs.pathParameters['id']!))),
      GoRoute(path: '/profile/saved', name: 'favorites', builder: (_, _) => const FavoritesScreen()),

      // ---------- 5-tab shell ----------
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', name: 'home',
              builder: (_, _) => auth is AuthAuthenticated ? const HomeScreen() : const _SplashScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/search', name: 'search', builder: (_, _) => const ListingsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/notifications', name: 'notifications', builder: (_, _) => const NotificationsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/chats', name: 'chats', builder: (_, _) => const ChatsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', name: 'profile', builder: (_, _) => const ProfileScreen(),
              routes: [
                // My orders / my listings stay inside the Profile tab — the bar should remain visible while browsing them
                GoRoute(path: 'orders', name: 'profile-orders', builder: (_, _) => const OrdersScreen()),
                GoRoute(path: 'listings', name: 'profile-listings', builder: (_, _) => const ListingsScreen()),
              ]),
          ]),
        ],
      ),
    ],
  );
});
