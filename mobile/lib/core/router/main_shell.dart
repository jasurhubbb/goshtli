// MainShell — the bottom-tab-bar Scaffold that wraps the 5 tab branches from app_router.
//
// Uses go_router's StatefulShellRoute.indexedStack so each tab maintains its own navigation state (scrolling position,
// back stack within the tab) when the user switches tabs. Mirrors how iOS native bottom-tab apps behave.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';


class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const MainShell({super.key, required this.navigationShell});

  /// Switch tabs while preserving each tab's internal navigation state — second tap on the active tab pops to its root.
  void _onTap(int index) => navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final destinations = <NavigationDestination>[
      NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: t.tabHome),
      NavigationDestination(icon: const Icon(Icons.search_outlined), selectedIcon: const Icon(Icons.search), label: t.tabSearch),
      NavigationDestination(icon: const Icon(Icons.notifications_outlined), selectedIcon: const Icon(Icons.notifications),
                            label: t.tabNotifications),
      NavigationDestination(icon: const Icon(Icons.forum_outlined), selectedIcon: const Icon(Icons.forum), label: t.tabChats),
      NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: t.tabProfile),
    ];
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onTap,
        destinations: destinations,
        // Lighter background + indicator opacity gives the bar an iOS-y restrained feel
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}
