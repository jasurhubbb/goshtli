// MainShell — the bottom-tab Scaffold that wraps the 4 tab branches (Menyu / Savat / Buyurtmalar / Profil) from
// app_router. The Notifications and Chats screens still exist as top-level routes for deep links from push
// notifications, but they're no longer in the bottom bar after the v3.1 cart-first redesign.
//
// Sits between the active branch's Scaffold body and the bottom NavigationBar. CartFloatingBar rides above the
// tab bar ONLY on the Menyu tab — that's the only tab where users are browsing products and can add to cart.
// On Savat the bar duplicates the cart screen; on Buyurtmalar / Profil it's a distraction unrelated to the
// tab's purpose. CartFloatingBar still self-hides when the cart is empty. StatefulShellRoute.indexedStack keeps
// each tab's nav stack across switches.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/cart/presentation/cart_floating_bar.dart';
import '../../l10n/app_localizations.dart';


class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const MainShell({super.key, required this.navigationShell});

  // Branch indexes — v3.8 added Servislar between Menyu and Savat. Keep these in sync with the
  // ordering in app_router.dart's StatefulShellRoute branches.
  static const _menuIndex = 0;
  static const _servicesIndex = 1;
  static const _cartIndex = 2;
  static const _ordersIndex = 3;
  static const _profileIndex = 4;

  /// Switch tabs while preserving each tab's internal navigation state — a second tap on the active tab pops to root.
  void _onTap(int index) => navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    // Menyu is the only tab where the floating cart pill belongs — the rest manage cart/orders/account directly.
    final showFloatingCart = navigationShell.currentIndex == _menuIndex;

    final destinations = <NavigationDestination>[
      NavigationDestination(icon: const Icon(Icons.menu_book_outlined),
                            selectedIcon: const Icon(Icons.menu_book), label: t.tabMenu),
      NavigationDestination(icon: const Icon(Icons.handyman_outlined),
                            selectedIcon: const Icon(Icons.handyman), label: t.tabServices),
      NavigationDestination(icon: const Icon(Icons.shopping_basket_outlined),
                            selectedIcon: const Icon(Icons.shopping_basket), label: t.tabCart),
      NavigationDestination(icon: const Icon(Icons.receipt_long_outlined),
                            selectedIcon: const Icon(Icons.receipt_long), label: t.tabOrders),
      NavigationDestination(icon: const Icon(Icons.person_outline),
                            selectedIcon: const Icon(Icons.person), label: t.tabProfile),
    ];

    return Scaffold(
      body: navigationShell,
      // Stack the floating cart pill above the NavigationBar so it appears on every tab. CartFloatingBar handles its
      // own visibility (hides when cart is empty); we additionally hide on the Savat tab itself.
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        if (showFloatingCart) CartFloatingBar(onNavigateToCart: () => _onTap(_cartIndex)),
        // v3.8 — added Servislar = 5 tabs. NavigationBar's default label style (Material 3
        // labelMedium ≈ 12sp) wrapped long UZ labels like "Buyurtmalar" / "Servislar" onto two
        // lines on narrower phones. Force a tighter labelTextStyle here so all 5 labels fit on a
        // single line without truncation. height: 1.0 collapses the line-box so even a forced wrap
        // (extreme small screens) doesn't push the bar height up.
        NavigationBarTheme(
          data: const NavigationBarThemeData(
            labelTextStyle: WidgetStatePropertyAll(TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.w600, height: 1.0,
              letterSpacing: -0.1))),
          child: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _onTap,
            destinations: destinations,
            elevation: 0,
            backgroundColor: cs.surface,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          )),
      ]),
    );
  }

  // Kept for callers that want symbolic access (e.g. deep-link router → which tab does this URL belong to).
  static int indexForPath(String path) {
    if (path.startsWith('/servislar')) return _servicesIndex;
    if (path.startsWith('/savat')) return _cartIndex;
    if (path.startsWith('/profile') || path == '/profile') return _profileIndex;
    if (path.startsWith('/orders') || path.contains('/profile/orders')) return _ordersIndex;
    return _menuIndex;
  }
}
