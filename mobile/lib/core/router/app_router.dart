// Centralized go_router config — single redirect function decides login/home routing based on AuthState.
//
// Routing rules:
//   - AuthInitial / AuthLoading → no redirect; splash route shows a spinner
//   - AuthUnauthenticated → force user to /login if they're elsewhere
//   - AuthAuthenticated → force user to / if they're on /login or /register
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/auth/providers/auth_state.dart';
import '../../features/dashboard/presentation/home_screen.dart';
import '../../features/listings/presentation/listing_create_screen.dart';
import '../../features/listings/presentation/listing_detail_screen.dart';
import '../../features/listings/presentation/listings_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/orders/presentation/order_detail_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';


/// Splash widget shown during AuthInitial — prevents the app from flashing the login screen on every cold start before /me resolves.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}


/// Provider that builds the GoRouter using the current AuthState. Recreated when auth changes; go_router's refreshListenable
/// pattern via riverpod_navigation isn't pulled in to keep deps lean — re-creating the router on auth change is cheap enough.
final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    // Single redirect — runs on every navigation; returns null to allow, or a path to force-redirect.
    redirect: (context, gstate) {
      final loc = gstate.matchedLocation;
      // While we're still resolving the stored token at startup, don't bounce the user anywhere
      if (auth is AuthInitial || auth is AuthLoading) return null;
      final loggedIn = auth is AuthAuthenticated;
      final atAuth = loc == '/login' || loc == '/register';
      if (!loggedIn && !atAuth) return '/login';     // protected route, no session → login
      if (loggedIn && atAuth) return '/';             // already logged in, don't show auth screens
      return null;
    },
    routes: [
      GoRoute(path: '/login', name: 'login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', name: 'register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/', name: 'home', builder: (_, _) =>
          auth is AuthAuthenticated ? const HomeScreen() : const _SplashScreen()),
      GoRoute(path: '/listings', name: 'listings', builder: (_, _) => const ListingsScreen(),
              routes: [
                GoRoute(path: 'new', name: 'listing-new', builder: (_, _) => const ListingCreateScreen()),
                GoRoute(path: ':id', name: 'listing-detail', builder: (_, gs) =>
                        ListingDetailScreen(listingId: int.parse(gs.pathParameters['id']!))),
              ]),
      GoRoute(path: '/orders', name: 'orders', builder: (_, _) => const OrdersScreen(),
              routes: [GoRoute(path: ':id', name: 'order-detail', builder: (_, gs) =>
                       OrderDetailScreen(orderId: int.parse(gs.pathParameters['id']!)))]),
      GoRoute(path: '/profile', name: 'profile', builder: (_, _) => const ProfileScreen()),
      GoRoute(path: '/notifications', name: 'notifications', builder: (_, _) => const NotificationsScreen()),
    ],
  );
});
