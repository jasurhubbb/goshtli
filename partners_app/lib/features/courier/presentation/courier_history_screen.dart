import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/courier_models.dart';
import '../providers/courier_providers.dart';
import '../../../shared/utils/format.dart';


/// Tarix — completed / cancelled deliveries. Read-only; taps open detail for photo proof + notes.
class CourierHistoryScreen extends ConsumerWidget {
  const CourierHistoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(deliveriesProvider('done'));
    final cs = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(deliveriesProvider('done')),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24),
            child: Center(child: Text(e.toString(), style: TextStyle(color: cs.error))))]),
        data: (rows) {
          if (rows.isEmpty) {
            return ListView(children: [
              const SizedBox(height: 80),
              Center(child: Column(children: [
                Icon(Icons.history_rounded, size: 72, color: cs.onSurfaceVariant),
                const SizedBox(height: 12),
                Text('Tarix bo\'sh', style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: cs.onSurfaceVariant)),
              ])),
            ]);
          }
          return ListView.builder(padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            itemBuilder: (_, i) => _HistoryTile(row: rows[i]));
        },
      ),
    );
  }
}


class _HistoryTile extends StatelessWidget {
  final DeliveryRow row;
  const _HistoryTile({required this.row});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDelivered = row.status == DeliveryStatus.delivered;
    final chipColor = isDelivered ? const Color(0xFF1B5E20) : cs.error;
    return InkWell(onTap: () => context.push('/courier/delivery/${row.id}'),
      borderRadius: BorderRadius.circular(14),
      child: Container(margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(
                color: chipColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(22)),
            child: Icon(isDelivered ? Icons.check_rounded : Icons.close_rounded,
                color: chipColor, size: 24)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('#${row.orderId}  ·  ${row.listingName}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('${row.quantityKg} kg · ${row.buyerName}',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 2),
            Text(row.deliveredAt ?? row.createdAt,
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(deliveryStatusLabel(row.status),
                style: tt.labelMedium?.copyWith(color: chipColor,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            if (isDelivered && row.payoutUzs > 0)
              Text("${formatSoum(row.payoutUzs)} so'm",
                  style: tt.labelSmall?.copyWith(color: cs.primary,
                      fontWeight: FontWeight.w800)),
          ]),
        ])));
  }
}
