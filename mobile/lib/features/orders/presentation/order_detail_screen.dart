// Order detail — Apple-style hero, dotted timeline showing lifecycle progression, grouped fact list, role-based CTAs.
//
// State machine mirror of backend (apps/orders/services.py):
//   PENDING → CONFIRMED → PROCESSING → IN_TRANSIT → DELIVERED  (forward, supplier-driven)
//   PENDING/CONFIRMED/PROCESSING → CANCELLED                    (supplier or, for PENDING-only, buyer)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/l10n/enum_labels.dart';
import '../../../shared/models/order.dart' as model;
import '../../auth/providers/auth_providers.dart';
import '../../auth/providers/auth_state.dart';
import '../../listings/providers/listings_providers.dart';
import '../providers/orders_providers.dart';


class OrderDetailScreen extends ConsumerWidget {
  final int orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final async = ref.watch(orderByIdProvider(orderId));
    return Scaffold(
      appBar: AppBar(title: Text(t.orderDetailTitle(orderId))),
      body: async.when(
        data: (order) => _Body(order: order),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(t.failedPrefix(e.toString())))),
      ),
    );
  }
}


class _Body extends ConsumerWidget {
  final model.Order order;
  const _Body({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final auth = ref.watch(authNotifierProvider);
    final isBuyer = auth is AuthAuthenticated && auth.user.email == order.buyerEmail;
    final isSupplier = auth is AuthAuthenticated && auth.user.email == order.supplierEmail;

    return SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Hero — listing title + total price, prominently displayed
        Text(order.listingTitle, style: tt.displaySmall),
        const SizedBox(height: 6),
        Text('${order.quantityKg.toStringAsFixed(2)} kg @ ${order.listingPricePerKg.toStringAsFixed(2)}',
             style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        Text(order.totalPrice.toStringAsFixed(2), style: tt.headlineLarge?.copyWith(color: cs.primary)),
        const SizedBox(height: 24),

        // Lifecycle timeline — refined with checkpoint dots
        _StatusTimeline(currentStatus: order.status),
        const SizedBox(height: 24),

        // Grouped facts — From / To / Address / Notes
        _GroupedList(items: [
          (t.orderFromLabel(''), order.supplierEmail),
          (t.orderToLabel(''), order.buyerEmail),
          (t.orderFieldDeliveryAddress, order.deliveryAddress),
          if (order.notes.isNotEmpty) (t.orderFieldNotes, order.notes),
        ]),
        const SizedBox(height: 28),

        // Buyer-side action — Cancel only on PENDING
        if (isBuyer && order.status == model.OrderStatus.pending)
          OutlinedButton.icon(icon: const Icon(Icons.cancel_outlined), label: Text(t.orderCancelButton),
            onPressed: () => _confirmAndCancel(context, ref, asBuyer: true)),
        // Supplier-side actions — buttons for legal next states
        if (isSupplier) ..._supplierActions(context, ref, order),
      ]));
  }

  /// Render one button per legal forward transition + a Cancel button when pre-transit.
  List<Widget> _supplierActions(BuildContext context, WidgetRef ref, model.Order order) {
    final t = AppLocalizations.of(context);
    final next = _nextStatusesForSupplier(order.status);
    if (next.isEmpty) {
      return [Padding(padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(t.orderTerminalNoActions(order.status.label(context)),
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)))];
    }
    // Forward action(s) as primary FilledButtons; cancel as outlined to de-emphasize the destructive path
    final widgets = <Widget>[];
    for (final s in next) {
      if (s == model.OrderStatus.cancelled) {
        widgets..add(const SizedBox(height: 8))
          ..add(OutlinedButton.icon(icon: const Icon(Icons.cancel_outlined),
            label: Text(_actionLabel(context, s)),
            onPressed: () => _confirmAndTransition(context, ref, s)));
      } else {
        widgets.add(FilledButton(onPressed: () => _confirmAndTransition(context, ref, s),
            child: Text(_actionLabel(context, s))));
      }
    }
    return widgets;
  }

  List<model.OrderStatus> _nextStatusesForSupplier(model.OrderStatus current) => switch (current) {
    model.OrderStatus.pending => [model.OrderStatus.confirmed, model.OrderStatus.cancelled],
    model.OrderStatus.confirmed => [model.OrderStatus.processing, model.OrderStatus.cancelled],
    model.OrderStatus.processing => [model.OrderStatus.inTransit, model.OrderStatus.cancelled],
    model.OrderStatus.inTransit => [model.OrderStatus.delivered],
    _ => const [],
  };

  Future<void> _confirmAndCancel(BuildContext context, WidgetRef ref, {required bool asBuyer}) async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: Text(t.orderCancelTitle),
      content: Text(t.orderCancelBody),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.no)),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t.orderCancelButton))]));
    if (ok != true) return;
    try {
      if (asBuyer) {
        await ref.read(ordersRepositoryProvider).cancelAsBuyer(order.id);
      } else {
        await ref.read(ordersRepositoryProvider).setSupplierStatus(order.id, model.OrderStatus.cancelled);
      }
      _refreshAll(ref);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _confirmAndTransition(BuildContext context, WidgetRef ref, model.OrderStatus to) async {
    if (to == model.OrderStatus.cancelled) return _confirmAndCancel(context, ref, asBuyer: false);
    try {
      await ref.read(ordersRepositoryProvider).setSupplierStatus(order.id, to);
      _refreshAll(ref);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _refreshAll(WidgetRef ref) {
    ref..invalidate(orderByIdProvider(order.id))..invalidate(myOrdersProvider)..invalidate(supplierOrdersProvider)
       ..invalidate(listingByIdProvider(order.listingId))..invalidate(listingsBrowseProvider)..invalidate(myListingsProvider);
  }

  String _actionLabel(BuildContext context, model.OrderStatus s) {
    final t = AppLocalizations.of(context);
    return switch (s) {
      model.OrderStatus.confirmed => t.orderActionConfirm,
      model.OrderStatus.processing => t.orderActionStartProcessing,
      model.OrderStatus.inTransit => t.orderActionMarkInTransit,
      model.OrderStatus.delivered => t.orderActionMarkDelivered,
      model.OrderStatus.cancelled => t.orderActionCancel,
      _ => s.name,
    };
  }
}


/// Vertical iOS-style lifecycle timeline — checkmarked dots for completed states, hollow for upcoming, red box for cancelled.
class _StatusTimeline extends StatelessWidget {
  final model.OrderStatus currentStatus;
  const _StatusTimeline({required this.currentStatus});

  static const _forward = [model.OrderStatus.pending, model.OrderStatus.confirmed,
                           model.OrderStatus.processing, model.OrderStatus.inTransit, model.OrderStatus.delivered];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    if (currentStatus == model.OrderStatus.cancelled) {
      return Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: cs.errorContainer.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14)),
        child: Row(children: [Icon(Icons.cancel_outlined, color: cs.onErrorContainer),
                              const SizedBox(width: 12),
                              Text(currentStatus.label(context), style: tt.titleMedium?.copyWith(color: cs.onErrorContainer))]));
    }
    final currentIdx = _forward.indexOf(currentStatus);
    return Column(children: [
      for (int i = 0; i < _forward.length; i++) Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Dot + connector line
        SizedBox(width: 28, child: Column(children: [
          Container(width: 14, height: 14,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: i <= currentIdx ? cs.primary : Colors.transparent,
              border: Border.all(color: i <= currentIdx ? cs.primary : cs.outlineVariant, width: 2)),
            child: i < currentIdx ? Icon(Icons.check, size: 10, color: cs.onPrimary) : null),
          if (i < _forward.length - 1)
            Container(width: 2, height: 24, color: i < currentIdx ? cs.primary : cs.outlineVariant.withValues(alpha: 0.5)),
        ])),
        const SizedBox(width: 12),
        Expanded(child: Padding(padding: const EdgeInsets.only(top: 0, bottom: 14),
          child: Text(_forward[i].label(context),
            style: i <= currentIdx ? tt.titleSmall : tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)))),
      ]),
    ]);
  }
}


/// Same iOS Settings-style grouped list as listing_detail_screen.dart — co-located here to avoid premature shared widget.
class _GroupedList extends StatelessWidget {
  final List<(String, String)> items;
  const _GroupedList({required this.items});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(decoration: BoxDecoration(color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5), width: 0.5)),
      child: Column(children: [
        for (int i = 0; i < items.length; i++) ...[
          Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 2, child: Text(items[i].$1, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant))),
              Expanded(flex: 3, child: Text(items[i].$2, style: tt.bodyMedium, textAlign: TextAlign.right)),
            ])),
          if (i < items.length - 1) Divider(height: 0.5, indent: 14, endIndent: 14,
              color: cs.outlineVariant.withValues(alpha: 0.5)),
        ],
      ]));
  }
}
