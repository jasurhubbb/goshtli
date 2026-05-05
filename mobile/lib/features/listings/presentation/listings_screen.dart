// Listings browse screen — Apple-style large title, generous spacing, refined cards with subtle status pills.
//
// SliverAppBar.large gives the iOS large-title-collapses-on-scroll feel; the search field + filter chips live
// just below the hero so they feel like a natural continuation of the title area.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/l10n/enum_labels.dart';
import '../../../shared/models/listing.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/providers/auth_state.dart';
import '../providers/listings_providers.dart';


class ListingsScreen extends ConsumerWidget {
  const ListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final browse = ref.watch(listingsBrowseProvider);
    final auth = ref.watch(authNotifierProvider);
    final isSupplier = auth is AuthAuthenticated && auth.user.isSupplier;

    return Scaffold(
      floatingActionButton: isSupplier ? FloatingActionButton.extended(
        onPressed: () => context.push('/listings/new'),
        icon: const Icon(Icons.add), label: Text(t.newListing)) : null,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(listingsBrowseProvider),
        child: CustomScrollView(slivers: [
          SliverAppBar.large(
            title: Text(t.listingsTitle),
            actions: [IconButton(icon: const Icon(Icons.refresh), tooltip: t.refresh,
                                  onPressed: () => ref.invalidate(listingsBrowseProvider))],
          ),
          const SliverToBoxAdapter(child: _FiltersBar()),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          browse.when(
            data: (page) => page.results.isEmpty
                ? SliverFillRemaining(hasScrollBody: false,
                    child: Center(child: Text(t.noListingsMatchFilters,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant))))
                : SliverPadding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: page.results.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _ListingCard(listing: page.results[i]))),
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


/// Filter chips row + search field — sits just below the large title; chips wrap horizontally with momentum scroll.
class _FiltersBar extends ConsumerWidget {
  const _FiltersBar();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final f = ref.watch(listingFiltersProvider);
    return Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: t.searchListingsHint),
          onChanged: (v) => ref.read(listingFiltersProvider.notifier).state =
              (meatType: f.meatType, location: f.location, priceMin: f.priceMin, priceMax: f.priceMax,
               search: v.isEmpty ? null : v, ordering: f.ordering)),
        const SizedBox(height: 10),
        SizedBox(height: 36, child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final mt in MeatType.values) Padding(padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: Text(mt.label(context)),
              selected: f.meatType == _wire(mt),
              onSelected: (sel) => ref.read(listingFiltersProvider.notifier).state =
                  (meatType: sel ? _wire(mt) : null, location: f.location, priceMin: f.priceMin,
                   priceMax: f.priceMax, search: f.search, ordering: f.ordering))),
        ])),
      ]));
  }

  static String _wire(MeatType t) => switch (t) {
    MeatType.beef => 'BEEF', MeatType.mutton => 'MUTTON', MeatType.chicken => 'CHICKEN',
    MeatType.goat => 'GOAT', MeatType.horse => 'HORSE', MeatType.other => 'OTHER',
  };
}


/// One row in the browse list — refined card with three-line layout: title, supplier+location, price+qty.
class _ListingCard extends StatelessWidget {
  final Listing listing;
  const _ListingCard({required this.listing});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/listings/${listing.id}'),
        child: Container(padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5), width: 0.5)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(listing.title, style: tt.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text('${listing.supplierBusinessName.isEmpty ? listing.supplierEmail : listing.supplierBusinessName}'
                   '  ·  ${listing.location}',
                   style: tt.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 10),
              Wrap(spacing: 6, children: [
                _Pill(text: listing.meatType.label(context), tone: _PillTone.neutral),
                if (listing.status != ListingStatus.active)
                  _Pill(text: listing.status.label(context), tone: _PillTone.warn),
              ]),
            ])),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(listing.pricePerKg.toStringAsFixed(0), style: tt.titleLarge),
              Text(t.perKgSuffix, style: tt.bodySmall),
              const SizedBox(height: 6),
              Text('${listing.quantityKg.toStringAsFixed(1)} ${t.kgAvailableSuffix}', style: tt.bodySmall),
            ]),
          ]))));
  }
}


enum _PillTone { neutral, warn }


/// Small pill — used for meat type and abnormal-status flags. Matches iOS subtle tag style.
class _Pill extends StatelessWidget {
  final String text;
  final _PillTone tone;
  const _Pill({required this.text, this.tone = _PillTone.neutral});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (bg, fg) = tone == _PillTone.warn
        ? (cs.errorContainer.withValues(alpha: 0.7), cs.onErrorContainer)
        : (cs.surfaceContainerHighest, cs.onSurfaceVariant);
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w500)));
  }
}
