// Orders list — Apple-style large title, refined cards with subtle status pills + grouped layout.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/l10n/enum_labels.dart';
import '../../../shared/models/order.dart' as model;
import '../../auth/providers/auth_providers.dart';
import '../../auth/providers/auth_state.dart';
import '../providers/orders_providers.dart';


class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final auth = ref.watch(authNotifierProvider);

    // v3.9.11 — distinguish auth states so the tab always renders SOMETHING useful. The previous
    // code returned a permanent spinner for anything that wasn't AuthAuthenticated, which meant
    // anonymous users tapping the Buyurtmalar tab saw a "loading forever" screen — the "sometimes
    // doesn't open" symptom.
    if (auth is AuthInitial || auth is AuthLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (auth is! AuthAuthenticated) {
      // Anonymous or session-expired — buyers need to sign in before they can have orders. Render
      // an empty-state illustration + Kirish CTA, wrapped in the same Scaffold shell so the tab
      // header is consistent with the authenticated view.
      return Scaffold(body: SafeArea(child: Center(
        child: Padding(padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: cs.onSurfaceVariant),
            const SizedBox(height: 14),
            Text(t.noOrdersYet, textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text("Buyurtmalarni ko'rish uchun tizimga kiring",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 20),
            FilledButton(onPressed: () => context.push('/auth/phone'),
                child: const Text("Kirish")),
          ])))));
    }
    final ordersAsync = auth.user.isSupplier ? ref.watch(supplierOrdersProvider) : ref.watch(myOrdersProvider);
    final providerToInvalidate = auth.user.isSupplier ? supplierOrdersProvider : myOrdersProvider;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(providerToInvalidate),
        child: CustomScrollView(slivers: [
          SliverAppBar.large(
            title: Text(auth.user.isSupplier ? t.incomingOrdersTitle : t.myOrdersTitle),
            actions: [IconButton(icon: const Icon(Icons.refresh), tooltip: t.refresh,
                                  onPressed: () => ref.invalidate(providerToInvalidate))],
          ),
          const SliverToBoxAdapter(child: _StatusFilterBar()),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          ordersAsync.when(
            data: (page) => page.results.isEmpty
                ? SliverFillRemaining(hasScrollBody: false,
                    child: Center(child: Padding(padding: const EdgeInsets.all(32),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        // Empty-with-icon layout mirrors the buyer-side Chats + Servislar tabs so the
                        // "nothing here yet" message reads as intentional design, not a bug.
                        Icon(Icons.receipt_long_outlined, size: 64, color: cs.onSurfaceVariant),
                        const SizedBox(height: 14),
                        Text(t.noOrdersYet, textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
                      ]))))
                : SliverPadding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: page.results.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _OrderCard(order: page.results[i]))),
            loading: () => const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()))),
            error: (e, _) => SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(24),
                child: Center(child: Text(t.failedPrefix(e.toString()))))),
          ),
        ]),
      ),
    );
  }
}


/// Status filter chips above the list — All + every OrderStatus value, horizontally scrollable.
class _StatusFilterBar extends ConsumerWidget {
  const _StatusFilterBar();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final selected = ref.watch(orderStatusFilterProvider);
    return Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: SizedBox(height: 36, child: ListView(scrollDirection: Axis.horizontal, children: [
        Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(
          label: Text(t.filterAll), selected: selected == null,
          onSelected: (_) => ref.read(orderStatusFilterProvider.notifier).state = null)),
        for (final s in model.OrderStatus.values) Padding(padding: const EdgeInsets.only(right: 6),
          child: ChoiceChip(
            label: Text(s.label(context)),
            selected: selected == s,
            onSelected: (_) => ref.read(orderStatusFilterProvider.notifier).state = selected == s ? null : s)),
      ])));
  }
}


class _OrderCard extends StatelessWidget {
  final model.Order order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/orders/${order.id}'),
        child: Container(padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5), width: 0.5)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('#${order.id}', style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(width: 8),
                Expanded(child: Text(order.listingTitle, style: tt.titleMedium,
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 4),
              Text('${order.quantityKg.toStringAsFixed(2)}kg  ·  ${order.totalPrice.toStringAsFixed(2)}',
                   style: tt.bodySmall),
              const SizedBox(height: 10),
              _StatusBadge(status: order.status),
            ])),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          ]))));
  }
}


/// Coloured status pill — primary container for delivered, error for cancelled, secondary for in-flight.
class _StatusBadge extends StatelessWidget {
  final model.OrderStatus status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status) {
      model.OrderStatus.delivered => (cs.tertiaryContainer.withValues(alpha: 0.7), cs.onTertiaryContainer),
      model.OrderStatus.cancelled => (cs.errorContainer.withValues(alpha: 0.7), cs.onErrorContainer),
      _ => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
    };
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(status.label(context), style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w500)));
  }
}
