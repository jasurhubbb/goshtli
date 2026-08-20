import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/catalog/catalog_screen.dart';
import '../../features/internal_account/internal_account_screen.dart';
import '../../features/orders_inbox/inbox_screen.dart';
import '../../l10n/app_localizations.dart';

/// Focused workspace for the platform's own catalog team.
///
/// The backend account still uses its legacy SUPPLIER role so existing listing and order APIs keep
/// working. This shell deliberately exposes only platform operations: listings first, then orders,
/// then the operator's account. There is no supplier profile, onboarding, earnings, or availability
/// surface.
class InternalCatalogShell extends ConsumerStatefulWidget {
  const InternalCatalogShell({super.key});

  @override
  ConsumerState<InternalCatalogShell> createState() =>
      _InternalCatalogShellState();
}

class _InternalCatalogShellState extends ConsumerState<InternalCatalogShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    const pages = [
      CatalogScreen(),
      InboxScreen(),
      InternalAccountScreen(),
    ];
    final titles = [
      t.internalCatalogTitle,
      t.tabOrders,
      t.internalAccountTitle,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_index]),
        actions: [
          if (_index == 0)
            IconButton(
              tooltip: t.catalogAddNew,
              onPressed: () async {
                final id = await context.push<int>('/catalog/new');
                if (id != null) ref.invalidate(myListingsProvider);
              },
              icon: const Icon(Icons.add_circle_outline_rounded),
            ),
          IconButton(
            tooltip: t.profileSectionNotifications,
            onPressed: () => context.push('/notifications'),
            icon: const Icon(Icons.notifications_outlined),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        height: 76,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.inventory_2_outlined),
            selectedIcon: const Icon(Icons.inventory_2_rounded),
            label: t.tabCatalog,
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long_rounded),
            label: t.tabOrders,
          ),
          NavigationDestination(
            icon: const Icon(Icons.manage_accounts_outlined),
            selectedIcon: const Icon(Icons.manage_accounts_rounded),
            label: t.internalAccountTitle,
          ),
        ],
      ),
    );
  }
}
