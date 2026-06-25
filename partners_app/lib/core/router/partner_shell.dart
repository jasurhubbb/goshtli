import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';

import '../../features/catalog/catalog_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/earnings/earnings_screen.dart';
import '../../features/orders_inbox/inbox_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/servisim/servisim_screen.dart';
import '../../l10n/app_localizations.dart';
import '../auth/partner_auth_notifier.dart';


/// 5-tab home shell. Tab 1 + 2 swap label/icon based on role:
///   QASSOB   → Ishlar  / Servisim
///   SUPPLIER → Buyurtmalar / Katalog
///
/// v3.9: qassobs' 3rd tab was Jadval (capacity calendar) which conflated capacity planning with the
/// concept of "their service offering". The new Servisim screen is the proper home for the qassob's
/// service-profile CRUD (bio / specialties / hours / prices / certifications / languages / gallery).
/// Capacity planning still exists as a backend concept but no longer takes a tab slot — when we
/// rebuild it, a "Sig'im jadvali" button inside Servisim will reach it.
class PartnerShell extends ConsumerStatefulWidget {
  const PartnerShell({super.key});
  @override
  ConsumerState<PartnerShell> createState() => _PartnerShellState();
}


class _PartnerShellState extends ConsumerState<PartnerShell> {
  int _idx = 0;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final auth = ref.watch(partnerAuthProvider);
    final isQ = auth is AuthAuthenticated && auth.user.isQassob;
    final pages = <Widget>[
      const DashboardScreen(),
      InboxScreen(isQassob: isQ),
      isQ ? const ServisimScreen() : const CatalogScreen(),
      const EarningsScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(_title(t, isQ)),
        // v3.9 — chat icon. Both qassobs and suppliers receive messages from buyers; the icon takes
        // them to the chats list. Pushed above the shell so the back arrow returns cleanly.
        actions: [IconButton(onPressed: () => context.push('/chats'),
            icon: const Icon(Icons.chat_bubble_outline_rounded))]),
      body: IndexedStack(index: _idx, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        height: 80,
        destinations: [
          NavigationDestination(icon: const Icon(Icons.dashboard_outlined),
              selectedIcon: const Icon(Icons.dashboard_rounded),
              label: t.tabHome),
          NavigationDestination(icon: const Icon(Icons.inbox_outlined),
              selectedIcon: const Icon(Icons.inbox_rounded),
              label: isQ ? t.tabJobs : t.tabOrders),
          NavigationDestination(
              icon: Icon(isQ ? Icons.handyman_outlined : Icons.list_alt_outlined),
              selectedIcon: Icon(isQ ? Icons.handyman_rounded : Icons.list_alt_rounded),
              label: isQ ? 'Servisim' : t.tabCatalog),
          NavigationDestination(icon: const Icon(Icons.bar_chart_outlined),
              selectedIcon: const Icon(Icons.bar_chart_rounded),
              label: t.tabEarnings),
          NavigationDestination(icon: const Icon(Icons.person_outline_rounded),
              selectedIcon: const Icon(Icons.person_rounded),
              label: t.tabProfile),
        ]),
    );
  }

  String _title(AppLocalizations t, bool isQ) {
    switch (_idx) {
      case 0: return t.tabHome;
      case 1: return isQ ? t.tabJobs : t.tabOrders;
      case 2: return isQ ? 'Servisim' : t.tabCatalog;
      case 3: return t.tabEarnings;
      case 4: return t.tabProfile;
      default: return t.appTitle;
    }
  }
}
