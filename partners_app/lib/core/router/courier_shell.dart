import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/courier/presentation/courier_active_screen.dart';
import '../../features/courier/presentation/courier_earnings_screen.dart';
import '../../features/courier/presentation/courier_history_screen.dart';
import '../../features/courier/presentation/courier_profile_screen.dart';
import '../../features/courier/presentation/courier_queue_screen.dart';


/// 5-tab shell for the COURIER role. Mirrors PartnerShell shape (NavigationBar + IndexedStack)
/// so hot-swap between roles feels the same, but with courier-specific tabs:
///   0: Bosh sahifa (queue + KPIs)   → CourierQueueScreen
///   1: Faol       (in-progress)      → CourierActiveScreen
///   2: Daromad    (earnings)         → CourierEarningsScreen
///   3: Tarix      (history)          → CourierHistoryScreen
///   4: Profil     (vehicle + logout) → CourierProfileScreen
class CourierShell extends ConsumerStatefulWidget {
  const CourierShell({super.key});
  @override
  ConsumerState<CourierShell> createState() => _CourierShellState();
}

class _CourierShellState extends ConsumerState<CourierShell> {
  int _idx = 0;

  static const _titles = ['Bosh sahifa', 'Faol', 'Daromad', 'Tarix', 'Profil'];

  @override
  Widget build(BuildContext context) {
    final pages = const [
      CourierQueueScreen(),
      CourierActiveScreen(),
      CourierEarningsScreen(),
      CourierHistoryScreen(),
      CourierProfileScreen(),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_idx])),
      body: IndexedStack(index: _idx, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        height: 80,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded), label: 'Bosh sahifa'),
          NavigationDestination(icon: Icon(Icons.local_shipping_outlined),
              selectedIcon: Icon(Icons.local_shipping_rounded), label: 'Faol'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart_rounded), label: 'Daromad'),
          NavigationDestination(icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history_rounded), label: 'Tarix'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded), label: 'Profil'),
        ]),
    );
  }
}
