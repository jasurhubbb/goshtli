import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';

import '../../core/auth/partner_auth_notifier.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/verification_banner.dart';
import '../availability/availability_provider.dart';
import 'dashboard_providers.dart';


/// Bosh sahifa — KPI tiles, smart tip, availability toggle, verification banner.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final auth = ref.watch(partnerAuthProvider);
    final async = ref.watch(dashboardProvider);
    final tips = ref.watch(smartTipsProvider);
    final user = auth is AuthAuthenticated ? auth.user : null;
    // v3.9: qassobs don't have an inventory concept, so "Kam zaxira" makes no sense for them.
    // "Yangi buyurtmalar" is also more naturally "Yangi takliflar" (new offers) for qassobs since
    // they receive butcher-service offers, not direct product orders. Branch the KPI grid below on
    // this flag to keep both flows clean without duplicating the whole tile-grid block.
    final isQassob = user?.isQassob ?? false;

    return RefreshIndicator(
      onRefresh: () => ref.read(dashboardProvider.notifier).refresh(),
      child: ListView(padding: EdgeInsets.zero, children: [
        async.when(
          loading: () => const SizedBox.shrink(),
          error: (e, st) => const SizedBox.shrink(),
          data: (d) => (d['is_verified'] == true) ? const SizedBox.shrink()
                       : const VerificationBanner()),
        Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
          child: Text(t.dashboardGreeting(user?.fullName ?? ''),
              style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Container(decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant)),
            child: SwitchListTile.adaptive(
              value: ref.watch(availabilityProvider),
              onChanged: (v) => ref.read(availabilityProvider.notifier).setOpen(v),
              title: Text(t.dashboardOpenNow,
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              secondary: Icon(Icons.power_settings_new_rounded, color: cs.primary)))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: async.when(
            loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Padding(padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text(e.toString(), style: TextStyle(color: cs.error)))),
            data: (d) => GridView.count(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2, childAspectRatio: 1.6,
              crossAxisSpacing: 12, mainAxisSpacing: 12,
              children: [
                // Defensive `?? "0"` — backend may omit fields or return null. UI shows "0", not the
                // literal string "null" which leaked through in v3.8.0.
                _Kpi(label: t.dashboardKpiTodayRevenue,
                      value: _fmtMoney(d['today_revenue']), accent: cs.primary),
                _Kpi(label: isQassob ? 'Yangi takliflar' : t.dashboardKpiOpenOrders,
                      value: _fmtCount(d['open_orders']), accent: const Color(0xFF1B5E20)),
                // Stock concept is supplier-only. For qassobs we swap in a "Tomonkun sig'imi" (today's
                // capacity slot) tile so the grid layout stays 2x2 — fallback to "0" until the
                // backend dashboard endpoint surfaces per-day capacity.
                if (isQassob)
                  _Kpi(label: "Bugungi sig'im",
                        value: _fmtCount(d['daily_capacity_head']),
                        accent: const Color(0xFFEF6C00))
                else
                  _Kpi(label: t.dashboardKpiLowStock,
                        value: _fmtCount(d['low_stock_count']),
                        accent: const Color(0xFFEF6C00)),
                _Kpi(label: t.dashboardKpiReviews,
                      value: _fmtCount(d['unread_reviews']), accent: const Color(0xFF6A1B9A)),
              ]))),
        Padding(padding: const EdgeInsets.fromLTRB(20, 22, 20, 6),
          child: Text(t.dashboardSmartTipsTitle,
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
        tips.when(
          loading: () => const SizedBox.shrink(),
          error: (e, st) => const SizedBox.shrink(),
          data: (ts) => Column(children: ts.take(3).map((tip) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: _TipCard(name: tip['name'] as String,
                            message: tip['message'] as String,
                            days: tip['days_until'] as int))).toList())),
        const SizedBox(height: 24),
      ]),
    );
  }
}


/// Defensive number formatters — backend can omit a key or return null when no data exists. We render
/// "0" instead of the literal string "null" leaking into the UI.
String _fmtCount(dynamic v) {
  if (v == null) return '0';
  if (v is num) return v.toString();
  return v.toString();
}

String _fmtMoney(dynamic v) {
  if (v == null) return '0';
  // Backend ships money fields as Decimal-stringified ("12345.00"). Trim trailing decimal noise.
  final s = v.toString();
  if (s.contains('.')) {
    final whole = s.split('.').first;
    return whole.isEmpty ? '0' : whole;
  }
  return s.isEmpty ? '0' : s;
}


class _Kpi extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  const _Kpi({required this.label, required this.value, required this.accent});
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
        const Spacer(),
        Text(value, style: tt.headlineSmall?.copyWith(
            color: accent, fontWeight: FontWeight.w900)),
      ]));
  }
}


class _TipCard extends StatelessWidget {
  final String name;
  final String message;
  final int days;
  const _TipCard({required this.name, required this.message, required this.days});
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFFFF4E5),
          borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF8A4F00)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(name, style: tt.titleSmall?.copyWith(
                color: const Color(0xFF8A4F00), fontWeight: FontWeight.w800))),
            Text(t.dashboardSmartTipDaysUntil(days),
                style: tt.bodySmall?.copyWith(color: const Color(0xFF8A4F00))),
          ]),
          const SizedBox(height: 4),
          Text(message, style: tt.bodySmall?.copyWith(color: const Color(0xFF8A4F00))),
        ])),
      ]));
  }
}
