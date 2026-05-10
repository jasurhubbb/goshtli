// Search screen — v2 Safia-style: search bar + filter chip row, then EITHER a flat filtered list (when a filter is set)
// OR a vertical stack of horizontally-scrolling rows grouped by meat type (Safia categories pattern).
//
// Layout logic:
//   • If listingFiltersProvider has any active filter (meat type, search text, price, location) → flat list view
//   • Otherwise → sectioned view, each meat type row shows up to 8 most-recent listings + "Barchasi" link
//
// The sectioned view fetches the broad paginated list once and groups client-side. Cheap for v2 traffic; if listings
// grow to thousands we'd add a backend "featured-by-category" endpoint to return N per type in one call.
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
    final filters = ref.watch(listingFiltersProvider);
    final auth = ref.watch(authNotifierProvider);
    final isSupplier = auth is AuthAuthenticated && auth.user.isSupplier;
    final anyFilter = filters.meatType != null || (filters.search?.isNotEmpty ?? false) ||
                      filters.priceMin != null || filters.priceMax != null ||
                      (filters.location?.isNotEmpty ?? false);

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
          // Branch 1 — any filter active → flat list (the existing v1 layout)
          if (anyFilter)
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
                        itemBuilder: (_, i) => _FlatListingCard(listing: page.results[i]))),
              loading: () => const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()))),
              error: (e, _) => SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(24),
                  child: Center(child: Text(t.failedPrefix(e.toString()))))),
            )
          // Branch 2 — no filter → sectioned view, one horizontal row per meat type that has ≥ 1 listing
          else
            browse.when(
              data: (page) => _SectionedSliver(listings: page.results),
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


/// Filter row pinned just below the large title — search field + meat type chip quick-picks.
class _FiltersBar extends ConsumerWidget {
  const _FiltersBar();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final f = ref.watch(listingFiltersProvider);
    return Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: TextField(
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: t.searchListingsHint),
            onChanged: (v) {
              ref.read(listingFiltersProvider.notifier).state = f.copyWith(search: () => v.isEmpty ? null : v);
            })),
          const SizedBox(width: 8),
          // v2: filter sheet button — opens the bottom sheet with halal / cold-chain / verified-only / service area
          IconButton.filledTonal(icon: const Icon(Icons.tune), tooltip: t.refresh,
            onPressed: () => _showFilterSheet(context, ref)),
        ]),
        const SizedBox(height: 10),
        SizedBox(height: 36, child: ListView(scrollDirection: Axis.horizontal, children: [
          // "All" pill clears the meat_type filter — visible when one is active
          if (f.meatType != null) Padding(padding: const EdgeInsets.only(right: 6),
            child: ActionChip(label: Text(t.filterAll), avatar: const Icon(Icons.close, size: 16),
              onPressed: () =>
                  ref.read(listingFiltersProvider.notifier).state = f.copyWith(meatType: () => null))),
          for (final mt in MeatType.values) Padding(padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: Text(mt.label(context)),
              selected: f.meatType == _wire(mt),
              onSelected: (sel) =>
                  ref.read(listingFiltersProvider.notifier).state =
                      f.copyWith(meatType: () => sel ? _wire(mt) : null))),
        ])),
      ]));
  }

  static String _wire(MeatType t) => switch (t) {
    MeatType.beef => 'BEEF', MeatType.mutton => 'MUTTON', MeatType.chicken => 'CHICKEN',
    MeatType.goat => 'GOAT', MeatType.horse => 'HORSE', MeatType.other => 'OTHER',
  };
}


/// Sectioned view — groups the loaded listings by meat type, emits one horizontal-scroll row per non-empty group.
/// Sections render in MeatType enum order so the visual order stays stable across reloads.
class _SectionedSliver extends ConsumerWidget {
  final List<Listing> listings;
  const _SectionedSliver({required this.listings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    if (listings.isEmpty) {
      return SliverFillRemaining(hasScrollBody: false,
        child: Center(child: Text(t.noListingsMatchFilters,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant))));
    }
    final byType = <MeatType, List<Listing>>{for (final mt in MeatType.values) mt: []};
    for (final l in listings) { byType[l.meatType]!.add(l); }
    final populatedTypes = byType.entries.where((e) => e.value.isNotEmpty).toList();

    return SliverList.list(children: [
      for (final entry in populatedTypes) _MeatTypeSection(
        title: entry.key.label(context),
        listings: entry.value,
        wireType: _MeatTypeSection._wire(entry.key)),
      const SizedBox(height: 24),
    ]);
  }
}


/// One section: header (title + "Barchasi") and a horizontal ListView of compact cards.
class _MeatTypeSection extends ConsumerWidget {
  final String title;
  final List<Listing> listings;
  final String wireType;
  const _MeatTypeSection({required this.title, required this.listings, required this.wireType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    return Padding(padding: const EdgeInsets.only(bottom: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Expanded(child: Text(title, style: tt.titleLarge)),
            TextButton(onPressed: () {
              final cur = ref.read(listingFiltersProvider);
              ref.read(listingFiltersProvider.notifier).state = cur.copyWith(meatType: () => wireType);
            }, child: Text('${t.viewAll} →')),
          ])),
        const SizedBox(height: 8),
        SizedBox(height: 220, child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemCount: listings.length,
          itemBuilder: (_, i) => _CompactCard(listing: listings[i]))),
      ]));
  }

  static String _wire(MeatType t) => switch (t) {
    MeatType.beef => 'BEEF', MeatType.mutton => 'MUTTON', MeatType.chicken => 'CHICKEN',
    MeatType.goat => 'GOAT', MeatType.horse => 'HORSE', MeatType.other => 'OTHER',
  };
}


/// Compact card used in horizontal section rows — fixed 170pt width, photo on top, title + price below.
class _CompactCard extends StatelessWidget {
  final Listing listing;
  const _CompactCard({required this.listing});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return SizedBox(width: 170, child: Material(
      color: cs.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/listings/${listing.id}'),
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5), width: 0.5)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Square-ish photo at the top of the card
            AspectRatio(aspectRatio: 1.4, child: _ThumbnailLarge(url: listing.primaryPhotoUrl)),
            Padding(padding: const EdgeInsets.all(10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(listing.title, style: tt.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(listing.location, style: tt.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Row(children: [
                  Text(listing.pricePerKg.toStringAsFixed(0), style: tt.titleSmall),
                  Text(' ${t.perKgSuffix}', style: tt.bodySmall),
                  if (listing.halalCertified) const Spacer(),
                  if (listing.halalCertified) Padding(padding: const EdgeInsets.only(left: 4),
                      child: _MiniPill(text: t.halal, tone: _PillTone.success)),
                ]),
              ])),
          ])))));
  }
}


/// Full-width flat card used when a filter is active (or in the supplier's My Listings view).
class _FlatListingCard extends StatelessWidget {
  final Listing listing;
  const _FlatListingCard({required this.listing});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/listings/${listing.id}'),
        child: Container(padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5), width: 0.5)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 84, height: 84, child: _ThumbnailLarge(url: listing.primaryPhotoUrl,
                borderRadius: 12)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(listing.title, style: tt.titleMedium,
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (listing.supplierVerified) Padding(padding: const EdgeInsets.only(left: 6),
                    child: Icon(Icons.verified, size: 16, color: cs.primary)),
              ]),
              const SizedBox(height: 4),
              Text('${listing.supplierBusinessName.isEmpty ? listing.supplierEmail : listing.supplierBusinessName}'
                   '  ·  ${listing.location}', style: tt.bodySmall,
                   maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Row(children: [
                Text(listing.pricePerKg.toStringAsFixed(0), style: tt.titleLarge),
                Text(' ${t.perKgSuffix}', style: tt.bodySmall),
                const Spacer(),
                Text('${listing.quantityKg.toStringAsFixed(1)} ${t.kgAvailableSuffix}', style: tt.bodySmall),
              ]),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: [
                _MiniPill(text: listing.meatType.label(context), tone: _PillTone.neutral),
                if (listing.halalCertified) _MiniPill(text: t.halal, tone: _PillTone.success),
                if (listing.status != ListingStatus.active)
                  _MiniPill(text: listing.status.label(context), tone: _PillTone.warn),
              ]),
            ])),
          ]))));
  }
}


/// Photo thumbnail used by both compact + flat cards. Fixed BoxFit.cover for consistent framing.
class _ThumbnailLarge extends StatelessWidget {
  final String? url;
  final double borderRadius;
  const _ThumbnailLarge({required this.url, this.borderRadius = 0});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fallback = Container(color: cs.surfaceContainerHighest,
      child: Icon(Icons.image_outlined, color: cs.onSurfaceVariant, size: 32));
    if (url == null || url!.isEmpty) {
      return borderRadius > 0
          ? ClipRRect(borderRadius: BorderRadius.circular(borderRadius), child: fallback)
          : fallback;
    }
    final img = Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback);
    return borderRadius > 0 ? ClipRRect(borderRadius: BorderRadius.circular(borderRadius), child: img) : img;
  }
}


/// Bottom sheet for the secondary filters — halal, cold chain, verified-only, service area, price range.
/// Stays simple: toggles + chip rows + Apply/Reset, no nested screens.
void _showFilterSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(context: context, isScrollControlled: true, builder: (sctx) {
    final t = AppLocalizations.of(sctx);
    var f = ref.read(listingFiltersProvider);
    return StatefulBuilder(builder: (sctx, setSheet) =>
      Padding(padding: EdgeInsets.only(left: 20, right: 20, top: 4,
                                       bottom: MediaQuery.of(sctx).viewInsets.bottom + 20),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(t.refresh, style: Theme.of(sctx).textTheme.titleLarge),
          const SizedBox(height: 16),
          SwitchListTile(contentPadding: EdgeInsets.zero,
            value: f.halalOnly ?? false, onChanged: (v) => setSheet(() => f = f.copyWith(halalOnly: () => v ? true : null)),
            title: Text(t.halal), secondary: const Icon(Icons.verified_outlined)),
          SwitchListTile(contentPadding: EdgeInsets.zero,
            value: f.verifiedOnly ?? false, onChanged: (v) => setSheet(() => f = f.copyWith(verifiedOnly: () => v ? true : null)),
            title: Text(t.profileVerified), secondary: const Icon(Icons.shield_outlined)),
          const SizedBox(height: 8),
          Text(t.listingFieldStatus.toUpperCase(),
            style: Theme.of(sctx).textTheme.labelSmall?.copyWith(
              color: Theme.of(sctx).colorScheme.onSurfaceVariant, letterSpacing: 0.6)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            ChoiceChip(label: Text(t.coldChainFresh), selected: f.coldChain == 'FRESH',
              onSelected: (s) => setSheet(() => f = f.copyWith(coldChain: () => s ? 'FRESH' : null))),
            ChoiceChip(label: Text(t.coldChainChilled), selected: f.coldChain == 'CHILLED',
              onSelected: (s) => setSheet(() => f = f.copyWith(coldChain: () => s ? 'CHILLED' : null))),
            ChoiceChip(label: Text(t.coldChainFrozen), selected: f.coldChain == 'FROZEN',
              onSelected: (s) => setSheet(() => f = f.copyWith(coldChain: () => s ? 'FROZEN' : null))),
          ]),
          const SizedBox(height: 16),
          TextField(controller: TextEditingController(text: f.serviceArea ?? ''),
            decoration: InputDecoration(labelText: t.serviceArea),
            onChanged: (v) => f = f.copyWith(serviceArea: () => v.isEmpty ? null : v)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () {
              ref.read(listingFiltersProvider.notifier).state =
                  (meatType: f.meatType, location: null, priceMin: null, priceMax: null,
                   search: f.search, ordering: f.ordering,
                   halalOnly: null, coldChain: null, serviceArea: null, verifiedOnly: null);
              Navigator.pop(sctx);
            }, child: Text(t.filterAll))),
            const SizedBox(width: 12),
            Expanded(child: FilledButton(onPressed: () {
              ref.read(listingFiltersProvider.notifier).state = f;
              Navigator.pop(sctx);
            }, child: Text(t.listingActionSave))),
          ]),
        ]))));
  });
}


enum _PillTone { neutral, warn, success }


class _MiniPill extends StatelessWidget {
  final String text;
  final _PillTone tone;
  const _MiniPill({required this.text, this.tone = _PillTone.neutral});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (bg, fg) = switch (tone) {
      _PillTone.warn => (cs.errorContainer.withValues(alpha: 0.7), cs.onErrorContainer),
      _PillTone.success => (cs.tertiaryContainer.withValues(alpha: 0.7), cs.onTertiaryContainer),
      _PillTone.neutral => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
    };
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w500)));
  }
}
