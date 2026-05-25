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

  // Branch indexes — kept as named constants so the floating-bar visibility logic and tab destinations stay in sync.
  static const _menuIndex = 0;
  static const _cartIndex = 1;
  static const _ordersIndex = 2;
  static const _profileIndex = 3;

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
        NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _onTap,
          destinations: destinations,
          elevation: 0,
          backgroundColor: cs.surface,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),
      ]),
    );
  }

  // Kept for callers that want symbolic access (e.g. deep-link router → which tab does this URL belong to).
  static int indexForPath(String path) {
    if (path.startsWith('/savat')) return _cartIndex;
    if (path.startsWith('/profile') || path == '/profile') return _profileIndex;
    if (path.startsWith('/orders') || path.contains('/profile/orders')) return _ordersIndex;
    return _menuIndex;
  }
}
