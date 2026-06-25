// HomeScreen (Menyu tab) — v3.1 catalog: location pill + search bar header, 2-column product grid below.
//
// Header design follows the food-delivery convention (Swiggy / Wolt / Zomato):
//   • Top row: small pin icon → currently-selected region → chevron-down. Tap to swap region via bottom sheet.
//   • Below: full-width rounded search box. Submit (Enter / search button) updates the listing filters and
//     triggers a server-side re-fetch (q param hits both name_uz and name_ru in apps/listings/filters.py).
//
// The greeting card + language picker + "pick what you'll cook" hint were removed — keeps the home calm and lets
// the products themselves do the talking. Language picker still lives in Profile → Ilova tili.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/models/listing.dart';
import '../../../shared/utils/format.dart';
import '../../addresses/presentation/address_sheet.dart';
import '../../addresses/providers/addresses_providers.dart';
import '../../cart/presentation/qty_editor_sheet.dart';
import '../../cart/providers/cart_providers.dart';
import '../../chats/presentation/chat_icon_with_badge.dart';
import '../../listings/providers/listings_providers.dart';


class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}


class _HomeScreenState extends ConsumerState<HomeScreen> {
  // ScrollController drives the sticky-chip-bar reveal. Threshold is roughly the height of the 4×2 grid:
  // once the user has scrolled past the in-content category grid, the sticky chip bar fades in at the top
  // so they can still switch categories without scrolling all the way back up.
  late final ScrollController _scrollCtl;
  bool _showStickyChips = false;
  static const _stickyChipThreshold = 240.0;

  @override
  void initState() {
    super.initState();
    _scrollCtl = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() { _scrollCtl.removeListener(_onScroll); _scrollCtl.dispose(); super.dispose(); }

  /// Single boolean toggle — only setState when crossing the threshold, not on every pixel scrolled.
  /// Stops the home screen from rebuilding 60 times per second during a flick scroll.
  void _onScroll() {
    final show = _scrollCtl.offset > _stickyChipThreshold;
    if (show != _showStickyChips) setState(() => _showStickyChips = show);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(activeListingsProvider);

    return Scaffold(
      // Stack lets the sticky chip bar float over the scroll view — a SliverPersistentHeader could do this
      // too but its shrinkOffset reveal animation is harder to make feel right. AnimatedSlide+Opacity is
      // explicit and predictable.
      body: Stack(children: [
        RefreshIndicator(
          onRefresh: () async => ref.invalidate(activeListingsProvider),
          child: CustomScrollView(
            controller: _scrollCtl,
            slivers: [
              // ---------- Header (location pill + chat icon + search bar) ----------
              // Top row puts the location pill on the left taking all remaining space, with the
              // chat icon pinned to the top-right corner — same anchor every food-delivery app
              // uses for "messages / notifications" (Swiggy, Wolt, Yandex Eda).
              SliverPadding(padding: const EdgeInsets.fromLTRB(16, 44, 8, 18),
                sliver: SliverList.list(children: const [
                  Row(children: [
                    Expanded(child: _LocationPill()),
                    ChatIconWithBadge(),
                  ]),
                  SizedBox(height: 22),
                  Padding(padding: EdgeInsets.only(right: 8), child: _SearchBar()),
                ])),

              // ---------- 4×2 category quick-pick grid (in-flow) ----------
              SliverPadding(padding: const EdgeInsets.fromLTRB(12, 6, 12, 18),
                sliver: const _CategoriesGrid()),

              // ---------- Product grid ----------
              async.when(
                data: (page) => page.results.isEmpty
                    ? const SliverFillRemaining(hasScrollBody: false,
                        child: Center(child: Padding(padding: EdgeInsets.all(48),
                            child: Text('Hozircha mahsulotlar yo\'q.', textAlign: TextAlign.center))))
                    : SliverPadding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 0.72),
                          delegate: SliverChildBuilderDelegate(
                            (_, i) => _ProductCard(listing: page.results[i]),
                            childCount: page.results.length))),
                loading: () => const SliverFillRemaining(hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator())),
                error: (e, _) => SliverFillRemaining(hasScrollBody: false,
                    child: Center(child: Padding(padding: const EdgeInsets.all(24),
                        child: Text(e.toString(), textAlign: TextAlign.center)))),
              ),
            ],
          ),
        ),

        // ---------- Sticky horizontal chip bar (overlays the top of the scroll view) ----------
        // Combined slide-from-top + fade — 280ms gives a calm reveal, not a jarring snap. Curves.easeOutCubic
        // is the iOS-y feel: decelerates as it settles. IgnorePointer when hidden so it doesn't intercept
        // taps meant for the content underneath.
        Positioned(top: 0, left: 0, right: 0,
          child: IgnorePointer(ignoring: !_showStickyChips,
            child: AnimatedSlide(
              offset: _showStickyChips ? Offset.zero : const Offset(0, -1),
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: _showStickyChips ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: const _StickyChipBar(),
              )))),
      ]),
    );
  }
}


// ---------- Header: location pill ----------

/// Single-line location pill — matches the Uzum Tezkor reference exactly:
///   📍  Uy · Bobur mahalla...arolar yig'ini, 6      ⌄
///
/// Format: "<label> · <street>" where the street is middle-elided so the START (mahalla / neighbourhood name)
/// AND END (the house number) both stay visible — couriers care most about those two endpoints. The middle
/// "fuqarolar yig'ini" type filler is the part that disappears with `...`.
///
/// Tap → opens the address bottom sheet (same flow for authenticated + anonymous; auth gate is at save-time,
/// not browse-time).
class _LocationPill extends ConsumerWidget {
  const _LocationPill();

  /// Custom middle-ellipsis truncator. Flutter's built-in TextOverflow.ellipsis only does END truncation,
  /// which would lose the house number ("...yig'ini, 6"). We compute the truncated string by hand: keep
  /// `startKeep` chars from the start, `endKeep` chars from the end, drop the rest, glue with '...'.
  static String _midEllipsis(String s, {int startKeep = 13, int endKeep = 18}) {
    if (s.length <= startKeep + endKeep + 3) return s;  // already fits — no truncation needed
    return '${s.substring(0, startKeep).trimRight()}...${s.substring(s.length - endKeep).trimLeft()}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final selectedAddress = ref.watch(selectedAddressProvider);
    final currentLocAsync = ref.watch(currentLocationProvider);

    // Resolve the displayed text. Four cases:
    //   1. Saved address selected → bold label + middle-elided street + house number
    //   2. currentLocationProvider still resolving → small spinner + "Aniqlanmoqda..." (don't show fallback)
    //   3. Anonymous-but-GPS-resolved → just the city/area name (no street known)
    //   4. Permission denied / GPS off → "Manzil tanlang" fallback (user taps to pick on map)
    final String label;
    final String? street;
    final bool loading;
    if (selectedAddress != null) {
      label = selectedAddress.label;
      street = _midEllipsis(selectedAddress.address);
      loading = false;
    } else if (currentLocAsync.isLoading) {
      label = 'Aniqlanmoqda';
      street = null;
      loading = true;
    } else {
      final loc = currentLocAsync.asData?.value;
      if (loc != null && loc.cityOrArea.isNotEmpty) {
        // Reverse-geocode-failed sentinel → render the localized "Mening joylashuvim" so the pill still
        // signals "location set" even when Nominatim couldn't pretty-name the city.
        label = loc.cityOrArea == kCurrentLocationFallbackLabel
            ? AppLocalizations.of(context).addressMapMyLocation
            : loc.cityOrArea;
        street = null;
      } else {
        label = 'Manzil tanlang';
        street = null;
      }
      loading = false;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        // Same destination for everyone — the sheet handles empty vs. populated lists itself.
        onTap: () { HapticFeedback.selectionClick(); showAddressSheet(context); },
        borderRadius: BorderRadius.circular(12),
        // 14pt vertical pad → ~56pt total tap zone (above the 48pt Material accessibility minimum)
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          child: Row(children: [
            // Spinner replaces the pin when the GPS+geocode chain is still resolving — signals "still working"
            // instead of looking like a permanent failure to detect.
            if (loading) SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary))
            else Icon(Icons.location_on_rounded, color: cs.primary, size: 26),
            const SizedBox(width: 8),
            // Compose a single line via Text.rich: bold-primary label + " · " separator + grey street.
            // street == null (anonymous, no saved address) → just the label.
            Expanded(child: Text.rich(
              TextSpan(children: [
                TextSpan(text: label,
                  style: tt.titleMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w800)),
                if (street != null) ...[
                  TextSpan(text: '  ·  ',
                    style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
                  TextSpan(text: street,
                    style: tt.titleMedium?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w500)),
                ],
              ]),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            )),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, color: cs.onSurface, size: 22),
          ])),
      ),
    );
  }
}


// ---------- Header: search bar ----------

/// Rounded search input. Submit-on-enter writes `q` into the listing filter, which triggers a re-fetch.
/// Clear button (`X`) on the right when there's text — single tap to reset the filter.
class _SearchBar extends ConsumerStatefulWidget {
  const _SearchBar();
  @override
  ConsumerState<_SearchBar> createState() => _SearchBarState();
}


class _SearchBarState extends ConsumerState<_SearchBar> {
  late final TextEditingController _ctl;

  @override
  void initState() {
    super.initState();
    // Mirror the persisted q value into the controller so a re-mount (tab switch) doesn't blow away the input
    _ctl = TextEditingController(text: ref.read(listingFiltersProvider).q ?? '');
  }

  @override
  void dispose() { _ctl.dispose(); super.dispose(); }

  void _submit() {
    final q = _ctl.text.trim();
    ref.read(listingFiltersProvider.notifier).update(
        (f) => f.copyWith(q: () => q.isEmpty ? null : q));
  }

  void _clear() {
    _ctl.clear();
    ref.read(listingFiltersProvider.notifier).update((f) => f.copyWith(q: () => null));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final hasText = _ctl.text.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5), width: 0.5)),
      child: TextField(
        controller: _ctl,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _submit(),
        onChanged: (_) => setState(() {}),  // rebuild so the clear (X) shows/hides as the user types
        decoration: InputDecoration(
          hintText: t.homeSearchHint,
          prefixIcon: Padding(padding: const EdgeInsets.only(left: 12, right: 8),
              child: Icon(Icons.search_rounded, color: cs.primary, size: 24)),
          prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          suffixIcon: hasText
              ? IconButton(icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant), onPressed: _clear)
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: InputBorder.none,
        )),
    );
  }
}


// ---------- Category quick-pick grid ----------

/// Catalog facet data hardcoded here for now. Slugs match what migration 0004_seed_meat_categories inserts.
/// When the backend gets a /api/v1/categories/ endpoint, replace this list with a FutureProvider that pulls
/// from there — the rest of the widget is shape-agnostic.
///
/// v3.4: icons are now PNG assets (per-meat-type illustrations in assets/categories/). Hammasi is the only
/// tile that keeps a Material icon — it's the all-clear filter, not a meat. The `iconAsset` field is null
/// for it; the tile widget falls back to `iconData` in that case.
class _Cat {
  final String slug, name;
  final IconData? iconData;
  final String? iconAsset;
  final int colorArgb;
  const _Cat(this.slug, this.name, this.colorArgb, {this.iconData, this.iconAsset})
      : assert((iconData == null) != (iconAsset == null),
            'Provide either iconData OR iconAsset — never both, never neither');
}

// First entry is the "Hammasi" all-clear filter — slug == '' means "no category filter active". The rest are
// the 7 meat-category buckets that match what migration 0004_seed_meat_categories inserts.
// "Boshqa" (the catch-all) was dropped from the grid to keep it a clean 4×2 = 8 tiles; it's still available
// in the sticky chip bar on scroll for completeness.
const _categories = <_Cat>[
  _Cat('',             'Hammasi',        0xFFFFF3E0, iconData: Icons.apps_rounded),
  _Cat('mol-goshti',   "Mol go'shti",    0xFFFCE4E4, iconAsset: 'assets/categories/cow.png'),
  _Cat('qoy-goshti',   "Qo'y go'shti",   0xFFFFE8D0, iconAsset: 'assets/categories/sheep.png'),
  _Cat('tovuq-goshti', "Tovuq go'shti",  0xFFFFF5D0, iconAsset: 'assets/categories/chicken.png'),
  _Cat('echki-goshti', "Echki go'shti",  0xFFE3F2FD, iconAsset: 'assets/categories/goat.png'),
  _Cat('ot-goshti',    "Ot go'shti",     0xFFEEEEFF, iconAsset: 'assets/categories/horse.png'),
  _Cat('qiyma',        'Qiyma',          0xFFFFEFD5, iconAsset: 'assets/categories/qiyma.png'),
  _Cat('jigar',        'Jigar',          0xFFFCE4EC, iconAsset: 'assets/categories/jigar.png'),
];


/// 4-column, 2-row tile grid. Each tile toggles a category filter on listingFiltersProvider. Tap the same
/// tile twice to clear the filter. Selected tile has a brand-coloured ring to signal active state.
class _CategoriesGrid extends ConsumerWidget {
  const _CategoriesGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSlug = ref.watch(listingFiltersProvider.select((f) => f.category));
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, mainAxisSpacing: 14, crossAxisSpacing: 8, childAspectRatio: 0.78),
      delegate: SliverChildBuilderDelegate(
        (_, i) {
          final c = _categories[i];
          // "Hammasi" (slug == '') is the active tile when no category filter is set; the rest match by slug.
          final isSelected = c.slug.isEmpty ? activeSlug == null : c.slug == activeSlug;
          return _CategoryTile(category: c, selected: isSelected);
        },
        childCount: _categories.length),
    );
  }
}


// ---------- Sticky chip bar (revealed on scroll) ----------

/// Horizontal scrollable list of category chips that floats over the top of the page once the user has
/// scrolled past the in-flow category grid. Hammasi is the FIRST chip (clears the filter); the same 8 meat
/// categories follow, mirroring the grid above.
///
/// Active state derives from the same listingFiltersProvider.category as the grid, so a tap on either
/// surface keeps both in sync.
class _StickyChipBar extends ConsumerWidget {
  const _StickyChipBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final activeSlug = ref.watch(listingFiltersProvider.select((f) => f.category));

    return Material(
      color: cs.surface,
      // Subtle elevation casts a soft shadow under the bar — clarifies that the products scroll BENEATH it
      elevation: 2,
      child: SafeArea(bottom: false, child: SizedBox(height: 56,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          children: [
            // "Hammasi" — leftmost; active when no category filter is set (i.e. browse-all mode)
            _StickyChip(label: 'Hammasi', selected: activeSlug == null,
              onTap: () => ref.read(listingFiltersProvider.notifier).update((f) => f.copyWith(category: () => null))),
            const SizedBox(width: 8),
            for (final c in _categories) ...[
              _StickyChip(label: c.name, selected: c.slug == activeSlug,
                onTap: () => ref.read(listingFiltersProvider.notifier).update(
                    (f) => f.copyWith(category: () => c.slug == activeSlug ? null : c.slug))),
              const SizedBox(width: 8),
            ],
          ],
        ))),
    );
  }
}


/// Single chip — fully rounded capsule, brand-filled when active, soft-tinted otherwise. Tap = haptic +
/// filter toggle. Keeps a comfortable 36pt height for finger taps.
class _StickyChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _StickyChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return InkWell(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant.withValues(alpha: 0.5),
            width: 0.5),
        ),
        child: Center(child: Text(label,
          style: tt.bodyMedium?.copyWith(
            color: selected ? cs.onPrimary : cs.onSurface,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          ))),
      ),
    );
  }
}


class _CategoryTile extends ConsumerWidget {
  final _Cat category;
  final bool selected;
  const _CategoryTile({required this.category, required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    // Special-case "Hammasi" (slug == '') so tapping it always clears the filter (no toggle ambiguity).
    // For real categories: tap selects, tap again deselects (returns to Hammasi/all).
    final isAll = category.slug.isEmpty;

    // Material(transparent) → InkWell pattern is the canonical way to give the InkWell a guaranteed Material
    // ancestor (needed for the ripple paint). The SizedBox.expand wrapping the Column ensures the InkWell's
    // hit area = the FULL tile bounds from the SliverGrid, not just the icon+label visual area. Without that,
    // taps in the empty space around the icon were silently ignored — the bug you ran into.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          ref.read(listingFiltersProvider.notifier).update((f) =>
              f.copyWith(category: () => isAll ? null : (selected ? null : category.slug)));
        },
        borderRadius: BorderRadius.circular(16),
        child: SizedBox.expand(child: Column(mainAxisAlignment: MainAxisAlignment.start, children: [
          // Coloured square holds the icon. Brand-ring border appears when this is the active filter.
          // Meat categories use a PNG asset (Image.asset); Hammasi keeps the Material icon as a fallback.
          Container(width: 56, height: 56,
            decoration: BoxDecoration(color: Color(category.colorArgb),
                borderRadius: BorderRadius.circular(16),
                border: selected ? Border.all(color: cs.primary, width: 2.5) : null),
            padding: const EdgeInsets.all(8),
            child: category.iconAsset != null
                ? Image.asset(category.iconAsset!, fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium)
                : Icon(category.iconData, size: 28, color: Colors.brown.shade700)),
          const SizedBox(height: 6),
          // labelSmall (~11pt) + maxLines:1 fits the longest names ("Tovuq go'shti", "Echki go'shti") on one
          // line at the tight 4-column width. Letter-spacing tightening gains a few extra pixels.
          Text(category.name,
            style: tt.labelSmall?.copyWith(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? cs.primary : cs.onSurface,
                height: 1.1, letterSpacing: -0.2),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center),
        ])),
      ),
    );
  }
}


// ---------- Product card ----------

/// One product tile — photo region on top, name + price + add/qty CTA on the bottom. Tapping the card opens
/// the detail screen; tapping the + (or stepper) interacts with the cart directly without leaving the grid.
class _ProductCard extends ConsumerWidget {
  final Listing listing;
  const _ProductCard({required this.listing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;
    // Only watch the row this card cares about — single-product rebuilds, not whole-grid
    final qty = ref.watch(cartProvider.select((s) => s.items[listing.id]?.qty ?? 0));

    return GestureDetector(
      onTap: () => context.push('/listings/${listing.id}'),
      child: Container(
        decoration: BoxDecoration(color: cs.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4), width: 0.5)),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Image region — Image.network if the listing has a photo, else a category-coloured icon fallback.
          // For live animals we overlay a "Tirik vazn" or "1 Bosh" badge per PRD §2 so the buyer can
          // distinguish live-from-raw at a glance (the carcass photo + amber badge changes the visual gestalt).
          Expanded(child: Stack(fit: StackFit.expand, children: [
            Container(color: cs.surfaceContainerHighest,
              child: listing.primaryPhotoUrl != null
                  ? Image.network(listing.primaryPhotoUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Center(child: Icon(Icons.image_outlined, size: 56, color: cs.onSurfaceVariant)))
                  : Center(child: Icon(
                      listing.isLiveAnimal ? Icons.pets_rounded : Icons.restaurant_outlined,
                      size: 56, color: cs.onSurfaceVariant))),
            if (listing.isLiveAnimal)
              Positioned(top: 8, left: 8, child: _LiveAnimalBadge(byHead: listing.isByHead)),
          ])),

          // Info region — name + price + add CTA
          Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(listing.displayName(lang),
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: RichText(text: TextSpan(
                  style: tt.titleSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w800),
                  children: [
                    TextSpan(text: '${formatSoum(listing.pricePerKg.toInt())} so\'m'),
                    TextSpan(text: '/kg', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  ]))),
                const SizedBox(width: 6),
                qty == 0
                    ? _AddPill(onTap: () { HapticFeedback.lightImpact(); ref.read(cartProvider.notifier).add(listing); })
                    : _CardStepper(qty: qty,
                        // PRD §1 step rule: stepper +/- bumps by 5kg (raw meat) or 1 head (live-by-head).
                        // The notifier knows the right amount from the listing's saleType; we just trigger.
                        onDec: () => ref.read(cartProvider.notifier).decByStep(listing.id),
                        onInc: () => ref.read(cartProvider.notifier).incByStep(listing.id),
                        // Display the unit suffix on the readout so the buyer doesn't confuse "10" with 10kg vs 10 heads.
                        unitLabel: listing.isByHead ? null : 'kg',
                        // Tap the number → typeable sheet. Max = current listing stock; allowZero=false
                        // here so accidentally typing 0 doesn't remove the row from inside the editor.
                        // PRD §1: minKg + unitLabel come from the listing — raw meat = 10kg min; live by
                        // head = 1 head.
                        onTapQty: () async {
                          final picked = await showQtyEditorSheet(context,
                              currentQty: qty,
                              maxKg: listing.quantityKg.toInt(),
                              minKg: listing.minOrderKg,
                              unitLabel: listing.isByHead ? 'bosh' : 'kg',
                              allowZero: false,
                              listingName: listing.nameUz);
                          if (picked != null) ref.read(cartProvider.notifier).setQty(listing.id, picked);
                        }),
              ]),
            ])),
        ])),
    );
  }
}


class _AddPill extends StatelessWidget {
  final VoidCallback onTap;
  const _AddPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(color: cs.primary, shape: const CircleBorder(),
      child: InkWell(customBorder: const CircleBorder(), onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.add, size: 18, color: cs.onPrimary))));
  }
}


class _CardStepper extends StatelessWidget {
  final int qty;
  final VoidCallback onDec, onInc;
  // Optional — when set, tapping the number opens the typeable qty editor. Card stepper, cart row, and
  // peek bar all pass this callback so the bulk-entry path is uniform across surfaces.
  final VoidCallback? onTapQty;
  // Suffix shown after the number on the readout ("kg" / null for headcount). PRD §2: live-by-head listings
  // suppress the unit since the badge already says "1 Bosh".
  final String? unitLabel;
  const _CardStepper({required this.qty, required this.onDec, required this.onInc, this.onTapQty,
                      this.unitLabel});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final label = unitLabel == null ? '$qty' : '$qty${unitLabel!}';
    // Width widens slightly to accommodate the "kg" suffix without truncation. 22pt fit "99"; we need ~44pt
    // for "100kg" without crowding the +/- buttons.
    final readoutWidth = unitLabel == null ? 22.0 : 44.0;
    return Container(decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _Step(icon: Icons.remove, onTap: () { HapticFeedback.selectionClick(); onDec(); }, fg: cs.onPrimary),
        // Tappable number — InkResponse so the tap target is the same size as the visible text + a bit more.
        InkResponse(onTap: onTapQty == null ? null : () { HapticFeedback.selectionClick(); onTapQty!(); },
          radius: 18,
          child: SizedBox(width: readoutWidth, child: Center(child: Text(label,
            style: tt.bodyMedium?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w800))))),
        _Step(icon: Icons.add, onTap: () { HapticFeedback.selectionClick(); onInc(); }, fg: cs.onPrimary),
      ]));
  }
}


/// Small amber badge overlaid on live-animal product photos. PRD §2 specifies "Tirik vazn" (live weight) or
/// "1 Bosh" (1 head) — choice depends on the listing's sale type so the buyer instantly knows which math
/// applies in the cart (kg vs heads).
class _LiveAnimalBadge extends StatelessWidget {
  final bool byHead;
  const _LiveAnimalBadge({required this.byHead});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final label = byHead ? t.liveAnimalBadgeByHead : t.liveAnimalBadgeByWeight;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE0B2),                                  // PRD-matched soft amber
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.pets_rounded, size: 12, color: Color(0xFF5D3A00)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF5D3A00), letterSpacing: 0.2)),
      ]));
  }
}


class _Step extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color fg;
  const _Step({required this.icon, required this.onTap, required this.fg});

  @override
  Widget build(BuildContext context) {
    return InkResponse(onTap: onTap, radius: 18,
      child: Padding(padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 16, color: fg)));
  }
}
