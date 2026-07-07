import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/courier_models.dart';
import '../providers/courier_providers.dart';
import '../../../shared/utils/format.dart';


/// "Faol" tab — deliveries that are actively in progress (PICKED_UP + EN_ROUTE + ARRIVED).
///
/// This is the courier's working set — usually 1–2 rows. Tapping a row opens the detail screen
/// where they hit the state-advance buttons + upload photo proof.
class CourierActiveScreen extends ConsumerWidget {
  const CourierActiveScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(deliveriesProvider('active'));
    final cs = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(deliveriesProvider('active')),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24),
            child: Center(child: Text(e.toString(), style: TextStyle(color: cs.error))))]),
        data: (rows) {
          if (rows.isEmpty) {
            return ListView(children: [
              const SizedBox(height: 80),
              Center(child: Column(children: [
                Icon(Icons.local_shipping_outlined, size: 80, color: cs.onSurfaceVariant),
                const SizedBox(height: 16),
                Text("Faol yetkazishlar yo'q", style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text('Yangi topshiriqni "Bosh sahifa" tabidan qabul qiling',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant))),
              ])),
            ]);
          }
          return ListView.builder(padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            itemBuilder: (_, i) => _ActiveCard(row: rows[i]));
        },
      ),
    );
  }
}


class _ActiveCard extends StatelessWidget {
  final DeliveryRow row;
  const _ActiveCard({required this.row});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final (statusColor, statusText) = _colorFor(row.status);
    return InkWell(onTap: () => context.push('/courier/delivery/${row.id}'),
      borderRadius: BorderRadius.circular(16),
      child: Container(margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: statusColor.withValues(alpha: 0.30), width: 1.5),
            boxShadow: [BoxShadow(color: statusColor.withValues(alpha: 0.08),
                blurRadius: 8, offset: const Offset(0, 2))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999)),
              child: Text(statusText, style: tt.labelMedium?.copyWith(
                  color: statusColor, fontWeight: FontWeight.w900))),
            const Spacer(),
            Text('#${row.orderId}', style: tt.labelMedium?.copyWith(
                color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          Text(row.listingName, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text('${row.quantityKg} kg · ${row.buyerName}',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          Row(children: [
            Icon(Icons.home_rounded, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(child: Text(row.dropoffAddress.isNotEmpty ? row.dropoffAddress : "Manzil yo'q",
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: tt.bodySmall)),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: cs.onSurfaceVariant),
          ]),
          if (row.payoutUzs > 0) ...[
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: const Color(0xFF1B5E20).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8)),
              child: Text("Sizning ulushingiz: ${formatSoum(row.payoutUzs)} so'm",
                  style: tt.labelMedium?.copyWith(
                      color: const Color(0xFF1B5E20), fontWeight: FontWeight.w800))),
          ],
        ])));
  }

  (Color, String) _colorFor(DeliveryStatus s) => switch (s) {
    DeliveryStatus.pickedUp => (const Color(0xFF0D47A1), 'Olindi'),
    DeliveryStatus.enRoute  => (const Color(0xFFEF6C00), "Yo'lda"),
    DeliveryStatus.arrived  => (const Color(0xFF6A1B9A), 'Yetib bordi'),
    _                       => (Colors.grey, deliveryStatusLabel(s)),
  };
}
