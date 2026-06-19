import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';

import '../../features/calendar/calendar_screen.dart';
import '../../features/catalog/catalog_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/earnings/earnings_screen.dart';
import '../../features/orders_inbox/inbox_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../l10n/app_localizations.dart';
import '../auth/partner_auth_notifier.dart';


/// 5-tab home shell. Tab 1 + 2 swap label/icon based on role:
///   QASSOB  → Ishlar / Jadval
///   SUPPLIER → Buyurtmalar / Katalog
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
      isQ ? const CalendarScreen() : const CatalogScreen(),
      const EarningsScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(_title(t, isQ))),
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
              icon: Icon(isQ ? Icons.calendar_today_outlined : Icons.list_alt_outlined),
              selectedIcon: Icon(isQ ? Icons.calendar_today_rounded : Icons.list_alt_rounded),
              label: isQ ? t.tabSchedule : t.tabCatalog),
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
      case 2: return isQ ? t.tabSchedule : t.tabCatalog;
      case 3: return t.tabEarnings;
      case 4: return t.tabProfile;
      default: return t.appTitle;
    }
  }
}
