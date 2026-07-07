import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/utils/format.dart';
import '../data/courier_models.dart';
import '../providers/courier_providers.dart';


/// Home / Queue tab.
///
/// Layout:
///   • Sticky header — availability switch + today's earnings + active/queue KPIs
///   • ASSIGNED deliveries list (pull-to-refresh)
///
/// This is the courier's primary landing screen — everything they need in the moment.
class CourierQueueScreen extends ConsumerWidget {
  const CourierQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(courierDashboardProvider);
    final queueAsync = ref.watch(deliveriesProvider('queue'));
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(courierDashboardProvider);
        ref.invalidate(deliveriesProvider('queue'));
      },
      child: ListView(padding: EdgeInsets.zero, children: [
        _DashboardCard(async: dashAsync,
            onToggle: (v) async {
              await ref.read(courierRepoProvider).setOnline(v);
              ref.invalidate(courierDashboardProvider);
              ref.invalidate(courierMeProvider);
            }),
        Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Row(children: [
            const Icon(Icons.inbox_rounded, size: 20),
            const SizedBox(width: 8),
            Text("Yangi topshiriqlar",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900)),
          ])),
        _QueueList(async: queueAsync),
        const SizedBox(height: 24),
      ]),
    );
  }
}


class _DashboardCard extends StatelessWidget {
  final AsyncValue<CourierDashboard?> async;
  final ValueChanged<bool> onToggle;
  const _DashboardCard({required this.async, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return async.when(
      loading: () => const SizedBox(height: 220,
          child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Padding(padding: const EdgeInsets.all(24),
          child: Center(child: Text(e.toString(), style: TextStyle(color: cs.error)))),
      data: (d) {
        if (d == null) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [cs.primary.withValues(alpha: 0.14),
                          cs.primary.withValues(alpha: 0.04)])),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Availability switch row
            Row(children: [
              Icon(d.isOnline ? Icons.circle : Icons.circle_outlined,
                  size: 14,
                  color: d.isOnline ? const Color(0xFF1B5E20) : cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(d.isOnline ? "Faol - buyurtma qabul qilaman" : "Faol emas",
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800,
                      color: d.isOnline ? const Color(0xFF1B5E20) : cs.onSurfaceVariant)),
              const Spacer(),
              Switch.adaptive(value: d.isOnline, onChanged: onToggle),
            ]),
            const SizedBox(height: 14),
            // Today's earnings — the biggest, most motivating number
            Text("Bugungi daromad", style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text("${formatSoum(d.todayEarningsUzs)} so'm",
                style: tt.displaySmall?.copyWith(color: cs.primary,
                    fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            Text("${d.todayDeliveries} ta yetkazish",
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            // 3-across KPI row
            Row(children: [
              Expanded(child: _KpiTile(label: "Navbatda",
                  value: '${d.queueCount}', color: const Color(0xFF0D47A1))),
              const SizedBox(width: 10),
              Expanded(child: _KpiTile(label: "Faol",
                  value: '${d.activeCount}', color: const Color(0xFFEF6C00))),
              const SizedBox(width: 10),
              Expanded(child: _KpiTile(label: "Reyting",
                  value: d.ratingCount > 0
                      ? '${d.ratingAvg.toStringAsFixed(1)}★'
                      : '—',
                  color: const Color(0xFFB71C1C))),
            ]),
          ]));
      },
    );
  }
}


class _KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _KpiTile({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.30))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: tt.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(value, style: tt.titleLarge?.copyWith(
            color: color, fontWeight: FontWeight.w900)),
      ]));
  }
}


class _QueueList extends ConsumerWidget {
  final AsyncValue<List<DeliveryRow>> async;
  const _QueueList({required this.async});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return async.when(
      loading: () => const Padding(padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Padding(padding: const EdgeInsets.all(24),
          child: Center(child: Text(e.toString(), style: TextStyle(color: cs.error)))),
      data: (rows) {
        if (rows.isEmpty) {
          return Padding(padding: const EdgeInsets.fromLTRB(32, 40, 32, 24),
            child: Center(child: Column(children: [
              Icon(Icons.check_circle_outline_rounded,
                  size: 56, color: cs.onSurfaceVariant),
              const SizedBox(height: 12),
              Text("Yangi topshiriqlar yo'q",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text("Faol tugmasini yoqing va yangi buyurtmalarni kuting",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant)),
            ])));
        }
        return Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Column(children: rows.map((r) => _DeliveryCard(row: r)).toList()));
      },
    );
  }
}


class _DeliveryCard extends StatelessWidget {
  final DeliveryRow row;
  const _DeliveryCard({required this.row});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return InkWell(onTap: () => context.push('/courier/delivery/${row.id}'),
      borderRadius: BorderRadius.circular(16),
      child: Container(margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('#${row.orderId}  ·  ${row.listingName}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
            Text("${formatSoum(int.tryParse(row.totalPrice.split('.').first) ?? 0)} so'm",
                style: tt.titleSmall?.copyWith(color: cs.primary,
                    fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 4),
          Text('${row.quantityKg} kg · ${row.buyerName}',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          _AddressLine(icon: Icons.storefront_rounded,
              label: 'Olib ketish', text: row.pickupAddress),
          const SizedBox(height: 6),
          _AddressLine(icon: Icons.home_rounded,
              label: 'Yetkazish', text: row.dropoffAddress),
        ])));
  }
}


class _AddressLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String text;
  const _AddressLine({required this.icon, required this.label, required this.text});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: cs.onSurfaceVariant),
      const SizedBox(width: 8),
      Expanded(child: RichText(maxLines: 2, overflow: TextOverflow.ellipsis,
          text: TextSpan(style: tt.bodySmall?.copyWith(color: cs.onSurface), children: [
            TextSpan(text: '$label: ',
                style: TextStyle(color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700)),
            TextSpan(text: text.isNotEmpty ? text : "Ma'lumot yo'q"),
          ]))),
    ]);
  }
}
