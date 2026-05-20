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
import '../../reviews/presentation/review_submit_sheet.dart';
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

    return SingleChildScrollView(padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Coupang-style dark hero — prominent status banner up top with a heroic headline
        _StatusHero(order: order),

        Padding(padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Coupang-style horizontal step indicator — 5 icons in a row, completed states filled, upcoming hollow
            _HorizontalTimeline(currentStatus: order.status),
            const SizedBox(height: 24),

            // Item summary card — listing title + qty + total — clean rounded panel
            Container(padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: cs.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5), width: 0.5)),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(order.listingTitle, style: tt.titleMedium,
                       maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('${order.quantityKg.toStringAsFixed(2)} kg × ${order.listingPricePerKg.toStringAsFixed(0)}',
                       style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ])),
                Text(order.totalPrice.toStringAsFixed(0), style: tt.titleLarge?.copyWith(color: cs.primary)),
              ])),
            const SizedBox(height: 20),

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
            // Buyer-side review — only on DELIVERED orders. Backend rejects double-review at the DB-level.
            if (isBuyer && order.status == model.OrderStatus.delivered)
              FilledButton.icon(icon: const Icon(Icons.star_outline),
                label: Text(t.leaveReviewTitle),
                onPressed: () => showReviewSubmitSheet(context, ref,
                    orderId: order.id, supplierId: order.supplierUserId)),
            // Supplier-side actions — buttons for legal next states
            if (isSupplier) ..._supplierActions(context, ref, order),
          ])),
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


/// Coupang-style dark hero — full-bleed, prominent status headline + "Expected arrival" line.
/// Color is dark-on-light for active orders, error-tinted for cancelled, success-tinted for delivered.
class _StatusHero extends StatelessWidget {
  final model.Order order;
  const _StatusHero({required this.order});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    // Color palette switches based on terminal vs in-flight status
    final (bg, fg, headline, sub) = switch (order.status) {
      model.OrderStatus.cancelled => (cs.errorContainer, cs.onErrorContainer,
                                       'Order cancelled', 'Stock returned to seller'),
      model.OrderStatus.delivered => (cs.tertiaryContainer, cs.onTertiaryContainer,
                                       'Delivered ✓', 'Thanks for ordering'),
      model.OrderStatus.inTransit => (const Color(0xFF1F2937), Colors.white,
                                       'Out for delivery', 'On its way to you'),
      model.OrderStatus.processing => (const Color(0xFF1F2937), Colors.white,
                                       'Being prepared', 'Supplier is packaging your order'),
      model.OrderStatus.confirmed => (const Color(0xFF1F2937), Colors.white,
                                       'Confirmed', 'Supplier will start processing shortly'),
      model.OrderStatus.pending => (const Color(0xFF1F2937), Colors.white,
                                     'Waiting for supplier', 'Awaiting confirmation'),
    };
    return Container(width: double.infinity, padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      decoration: BoxDecoration(color: bg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('#${order.id}', style: tt.bodySmall?.copyWith(color: fg.withValues(alpha: 0.7))),
        const SizedBox(height: 6),
        Text(headline, style: tt.displaySmall?.copyWith(color: fg, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(sub, style: tt.bodyLarge?.copyWith(color: fg.withValues(alpha: 0.85))),
      ]));
  }
}


/// Horizontal stepper — 5 round nodes connected by dashes. Completed nodes solid+checkmark, current node solid+icon,
/// upcoming nodes hollow. Cancelled state shows a red full-width banner instead (returned from the switch above).
class _HorizontalTimeline extends StatelessWidget {
  final model.OrderStatus currentStatus;
  const _HorizontalTimeline({required this.currentStatus});

  static const _forward = [model.OrderStatus.pending, model.OrderStatus.confirmed,
                           model.OrderStatus.processing, model.OrderStatus.inTransit, model.OrderStatus.delivered];
  // Icons per step — paired by index with _forward
  static const _icons = [Icons.payments_outlined, Icons.thumb_up_alt_outlined,
                          Icons.kitchen_outlined, Icons.local_shipping_outlined, Icons.check_circle_outline];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    // Cancelled is a terminal state outside the forward path — show a clean cancellation banner instead of a stepper
    if (currentStatus == model.OrderStatus.cancelled) {
      return Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: cs.errorContainer.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(Icons.cancel_outlined, color: cs.onErrorContainer),
          const SizedBox(width: 12),
          Text(currentStatus.label(context), style: tt.titleMedium?.copyWith(color: cs.onErrorContainer)),
        ]));
    }
    final currentIdx = _forward.indexOf(currentStatus);
    return Column(children: [
      // Top row: circles + dashed connectors
      Row(children: [
        for (int i = 0; i < _forward.length; i++) ...[
          _StepNode(icon: _icons[i], state: i < currentIdx ? _StepState.done
                                            : i == currentIdx ? _StepState.current : _StepState.upcoming),
          if (i < _forward.length - 1) Expanded(child: Container(height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: i < currentIdx ? cs.primary : cs.outlineVariant.withValues(alpha: 0.5))),
        ],
      ]),
      const SizedBox(height: 8),
      // Bottom row: short labels under each circle
      Row(children: [
        for (int i = 0; i < _forward.length; i++) Expanded(
          child: Text(_forward[i].label(context),
            textAlign: TextAlign.center,
            style: tt.labelSmall?.copyWith(
              color: i <= currentIdx ? cs.onSurface : cs.onSurfaceVariant,
              fontWeight: i == currentIdx ? FontWeight.w600 : FontWeight.w500),
            maxLines: 2, overflow: TextOverflow.ellipsis)),
      ]),
    ]);
  }
}


enum _StepState { done, current, upcoming }


class _StepNode extends StatelessWidget {
  final IconData icon;
  final _StepState state;
  const _StepNode({required this.icon, required this.state});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (bg, fg, border) = switch (state) {
      _StepState.done => (cs.primary, cs.onPrimary, cs.primary),
      _StepState.current => (cs.primaryContainer, cs.onPrimaryContainer, cs.primary),
      _StepState.upcoming => (Colors.transparent, cs.onSurfaceVariant, cs.outlineVariant),
    };
    return Container(width: 32, height: 32,
      decoration: BoxDecoration(shape: BoxShape.circle, color: bg,
        border: Border.all(color: border, width: state == _StepState.upcoming ? 1.5 : 0)),
      child: Icon(state == _StepState.done ? Icons.check : icon, size: 16, color: fg));
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
