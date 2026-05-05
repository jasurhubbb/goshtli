// HomeScreen — role-based dashboard with iOS-style large title, refined stat tiles, grouped action lists.
//
// Layout: SliverAppBar.large for the iOS large-title-collapses-on-scroll feel, then sectioned content with generous spacing.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/language_picker.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/providers/auth_state.dart';
import '../../notifications/presentation/notifications_button.dart';
import '../providers/dashboard_providers.dart';


class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final auth = ref.watch(authNotifierProvider);
    if (auth is! AuthAuthenticated) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final user = auth.user;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(user.isSupplier ? supplierDashboardProvider : buyerDashboardProvider),
        // CustomScrollView lets the SliverAppBar.large collapse smoothly into a normal AppBar as user scrolls
        child: CustomScrollView(slivers: [
          SliverAppBar.large(
            title: Text(user.isSupplier ? t.supplierHome : t.buyerHome),
            actions: [
              const NotificationsButton(),
              const LanguagePicker(),
              IconButton(icon: const Icon(Icons.person_outline), tooltip: t.profile,
                         onPressed: () => context.push('/profile')),
              IconButton(icon: const Icon(Icons.logout), tooltip: t.logout,
                         onPressed: () => ref.read(authNotifierProvider.notifier).logout()),
            ],
          ),
          SliverPadding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            sliver: SliverList.list(children: [
              Text(t.greeting(user.fullName), style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 24),
              if (user.isSupplier) const _SupplierBody() else const _BuyerBody(),
            ])),
        ]),
      ),
    );
  }
}


/// Buyer view — order-status cards + grouped action list to Listings/Orders.
class _BuyerBody extends ConsumerWidget {
  const _BuyerBody();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final async = ref.watch(buyerDashboardProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _SectionHeader(text: t.sectionOrders),
      async.when(
        data: (d) => _StatGrid(stats: [
          (t.statPending, d.ordersPending, _StatTone.neutral),
          (t.statInProgress, d.ordersInProgress, _StatTone.accent),
          (t.statDelivered, d.ordersDelivered, _StatTone.success),
          (t.statCancelled, d.ordersCancelled, _StatTone.muted),
        ]),
        loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Text(t.failedPrefix(e.toString())),
      ),
      const SizedBox(height: 24),
      _GroupedActions(items: [
        _ActionItem(icon: Icons.storefront_outlined, label: t.browseListings, onTap: () => context.push('/listings')),
        _ActionItem(icon: Icons.receipt_long_outlined, label: t.myOrders, onTap: () => context.push('/orders')),
      ]),
    ]);
  }
}


/// Supplier view — verification banner if unverified, listings + orders stat grids, grouped action list.
class _SupplierBody extends ConsumerWidget {
  const _SupplierBody();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final async = ref.watch(supplierDashboardProvider);
    return async.when(
      data: (d) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (!d.isVerified) _VerificationBanner(text: t.verificationPendingBanner),
        if (!d.isVerified) const SizedBox(height: 20),
        _SectionHeader(text: t.sectionListings),
        _StatGrid(stats: [
          (t.statTotal, d.listingsTotal, _StatTone.neutral),
          (t.statActive, d.listingsActive, _StatTone.success),
          (t.statSoldOut, d.listingsSoldOut, _StatTone.accent),
          (t.statInactive, d.listingsInactive, _StatTone.muted),
        ]),
        const SizedBox(height: 24),
        _SectionHeader(text: t.sectionOrders),
        _StatGrid(stats: [
          (t.statPending, d.ordersPending, _StatTone.neutral),
          (t.statInProgress, d.ordersInProgress, _StatTone.accent),
          (t.statDelivered, d.ordersDelivered, _StatTone.success),
          (t.statCancelled, d.ordersCancelled, _StatTone.muted),
        ]),
        const SizedBox(height: 24),
        _GroupedActions(items: [
          _ActionItem(icon: Icons.list_alt_outlined, label: t.myListings, onTap: () => context.push('/listings')),
          _ActionItem(icon: Icons.inbox_outlined, label: t.incomingOrders, onTap: () => context.push('/orders')),
          if (d.isVerified) _ActionItem(icon: Icons.add_circle_outline, label: t.newListing,
                                         onTap: () => context.push('/listings/new')),
        ]),
      ]),
      loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Text(t.failedPrefix(e.toString())),
    );
  }
}


/// iOS-style section header — ALL CAPS, smaller, muted color, 8pt left padding to align with grouped lists.
class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader({required this.text});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 0, 8),
        child: Text(text.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 0.6,
              color: Theme.of(context).colorScheme.onSurfaceVariant)));
}


/// Reddish-tinted banner for the unverified-supplier case. Uses Card so it inherits the global rounded shape.
class _VerificationBanner extends StatelessWidget {
  final String text;
  const _VerificationBanner({required this.text});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: cs.errorContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(Icons.info_outline, color: cs.onErrorContainer), const SizedBox(width: 12),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onErrorContainer))),
      ]));
  }
}


enum _StatTone { neutral, accent, success, muted }


/// 2×N grid of stat tiles. Tones map to color choices so the eye can scan status faster than reading labels.
class _StatGrid extends StatelessWidget {
  final List<(String, int, _StatTone)> stats;
  const _StatGrid({required this.stats});
  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.9, mainAxisSpacing: 10, crossAxisSpacing: 10,
        children: [for (final (label, value, tone) in stats) _StatTile(label: label, value: value, tone: tone)]);
}


class _StatTile extends StatelessWidget {
  final String label; final int value; final _StatTone tone;
  const _StatTile({required this.label, required this.value, required this.tone});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (bg, fg) = switch (tone) {
      _StatTone.accent => (cs.primaryContainer.withValues(alpha: 0.5), cs.onPrimaryContainer),
      _StatTone.success => (cs.tertiaryContainer.withValues(alpha: 0.4), cs.onTertiaryContainer),
      _StatTone.muted => (cs.surfaceContainerHighest.withValues(alpha: 0.5), cs.onSurfaceVariant),
      _StatTone.neutral => (cs.secondaryContainer.withValues(alpha: 0.4), cs.onSecondaryContainer),
    };
    return Container(padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg.withValues(alpha: 0.85))),
        Text('$value', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: fg, fontWeight: FontWeight.w700)),
      ]));
  }
}


class _ActionItem {
  final IconData icon; final String label; final VoidCallback onTap;
  const _ActionItem({required this.icon, required this.label, required this.onTap});
}


/// iOS Settings-style grouped list — items inside one rounded surface, hairline dividers between rows.
class _GroupedActions extends StatelessWidget {
  final List<_ActionItem> items;
  const _GroupedActions({required this.items});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(decoration: BoxDecoration(color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5), width: 0.5)),
      child: Column(children: [
        for (int i = 0; i < items.length; i++) ...[
          ListTile(
            leading: Icon(items[i].icon, color: cs.primary),
            title: Text(items[i].label, style: Theme.of(context).textTheme.bodyLarge),
            trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            onTap: items[i].onTap,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          ),
          if (i < items.length - 1) Padding(padding: const EdgeInsets.only(left: 56),
              child: Divider(height: 0.5, color: cs.outlineVariant.withValues(alpha: 0.5))),
        ],
      ]));
  }
}
