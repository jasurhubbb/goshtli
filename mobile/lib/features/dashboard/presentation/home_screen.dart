// HomeScreen — v2 Safia-style redesign: hero greeting card, category tiles for meat types, verification banner
// for unverified suppliers, "Sotaman" floating action button.
//
// Categories deep-link into the Search tab pre-filtered by meat type — go() switches tabs, push() of /search would just
// stack a duplicate. Category tap → context.go('/search?meat=BEEF') (search screen reads the query param on build).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/models/listing.dart';
import '../../../shared/widgets/language_picker.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/providers/auth_state.dart';
import '../../listings/providers/listings_providers.dart';
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
      // FAB only for verified suppliers — unverified see the verification banner instead. Avoids the
      // "tap, get rejected" dead-end.
      floatingActionButton: _SellFab(user: user),
      body: CustomScrollView(slivers: [
        SliverAppBar.large(title: Text(t.appTitle), actions: const [LanguagePicker()]),
        SliverPadding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          sliver: SliverList.list(children: [
            _GreetingCard(name: user.fullName),
            const SizedBox(height: 20),
            const _VerificationBannerIfNeeded(),
            Text(t.sectionListings.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 0.6)),
            const SizedBox(height: 12),
            const _CategoryGrid(),
          ])),
      ]),
    );
  }
}


/// Hero card at the top — soft gradient + greeting + supplier/buyer flavor text.
/// This is where future "personalization" plugs in (recent orders preview, suggested listings, etc.)
class _GreetingCard extends StatelessWidget {
  final String name;
  const _GreetingCard({required this.name});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final t = AppLocalizations.of(context);
    return Container(padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [cs.primaryContainer.withValues(alpha: 0.7), cs.tertiaryContainer.withValues(alpha: 0.5)])),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t.greeting(name), style: tt.titleMedium?.copyWith(color: cs.onPrimaryContainer)),
        const SizedBox(height: 6),
        Text(t.welcomeSubtitle, style: tt.bodyMedium?.copyWith(color: cs.onPrimaryContainer.withValues(alpha: 0.85))),
      ]));
  }
}


/// Shown to unverified suppliers — visible inline so they can't miss it. Verified users see nothing here.
class _VerificationBannerIfNeeded extends ConsumerWidget {
  const _VerificationBannerIfNeeded();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final auth = ref.watch(authNotifierProvider);
    if (auth is! AuthAuthenticated || !auth.user.isSupplier) return const SizedBox.shrink();
    final async = ref.watch(supplierDashboardProvider);
    return async.maybeWhen(
      data: (d) {
        if (d.isVerified) return const SizedBox.shrink();
        final cs = Theme.of(context).colorScheme;
        return Padding(padding: const EdgeInsets.only(bottom: 20),
          child: Container(padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: cs.errorContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Icon(Icons.info_outline, color: cs.onErrorContainer), const SizedBox(width: 12),
              Expanded(child: Text(t.verificationPendingBanner,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onErrorContainer))),
            ])));
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}


/// 6-tile category grid — each tile drills into /search filtered by that meat type. Safia-style: soft tinted card,
/// icon up top, label below, generous touch target (~110pt tall).
class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    // Each entry: (meat type, icon, optional accent color via Material palette)
    final categories = <(MeatType, IconData, String)>[
      (MeatType.beef, Icons.set_meal_outlined, t.meatBeef),
      (MeatType.mutton, Icons.set_meal_outlined, t.meatMutton),
      (MeatType.chicken, Icons.egg_outlined, t.meatChicken),
      (MeatType.goat, Icons.pets_outlined, t.meatGoat),
      (MeatType.horse, Icons.sports_score_outlined, t.meatHorse),
      (MeatType.other, Icons.more_horiz, t.meatOther),
    ];
    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5, mainAxisSpacing: 12, crossAxisSpacing: 12,
      children: [for (final (m, icon, label) in categories) _CategoryTile(meatType: m, icon: icon, label: label)]);
  }
}


/// Single category tile — tap deep-links into Search tab with the meat-type pre-applied via Riverpod.
/// (Filter is applied through the filter notifier so back-stack still works.)
class _CategoryTile extends ConsumerWidget {
  final MeatType meatType;
  final IconData icon;
  final String label;
  const _CategoryTile({required this.meatType, required this.icon, required this.label});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: cs.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          // Apply the meat-type filter, then switch to the Search tab so the user lands on a pre-filtered list
          ref.read(listingFiltersProvider.notifier).state =
              ref.read(listingFiltersProvider).copyWith(meatType: () => _wire(meatType));
          context.go('/search');
        },
        child: Container(padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5), width: 0.5),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [cs.secondaryContainer.withValues(alpha: 0.4), cs.surfaceContainerLowest])),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Icon(icon, size: 28, color: cs.onSecondaryContainer),
            Text(label, style: tt.titleMedium),
          ]))));
  }

  static String _wire(MeatType t) => switch (t) {
    MeatType.beef => 'BEEF', MeatType.mutton => 'MUTTON', MeatType.chicken => 'CHICKEN',
    MeatType.goat => 'GOAT', MeatType.horse => 'HORSE', MeatType.other => 'OTHER',
  };
}


/// "Sotaman" FAB — only shown to verified suppliers so we don't dead-end other roles.
class _SellFab extends ConsumerWidget {
  final dynamic user;  // simpler than threading the full User type here for one boolean check
  const _SellFab({required this.user});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final async = ref.watch(supplierDashboardProvider);
    return async.maybeWhen(
      data: (d) => d.isVerified
          ? FloatingActionButton.extended(onPressed: () => context.push('/listings/new'),
              icon: const Icon(Icons.add), label: Text(t.newListing))
          : const SizedBox.shrink(),
      orElse: () => const SizedBox.shrink(),
    );
  }
}
