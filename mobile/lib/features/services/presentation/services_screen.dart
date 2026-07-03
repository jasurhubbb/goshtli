import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../data/qassob_models.dart';
import '../providers/services_providers.dart';


/// Servislar — modernized v3.9. Two carousels (Qassoblar / Qushxona xizmatlari) with a hero header
/// above the filter row so the chips don't crowd the status bar, larger photo-forward cards with an
/// overlay status badge + specialty-chip preview, and iOS-style bouncing scroll physics for a more
/// premium feel. Tapping a card pushes the buyer to `/servislar/{id}` (full detail page lives in
/// qassob_detail_screen.dart).
class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final filter = ref.watch(servicesAnimalFilterProvider);
    final all = ref.watch(qassobsListProvider);
    final slaughter = ref.watch(slaughterhouseListProvider);

    final filterRow = [
      (code: '', label: t.servicesFilterAll, icon: Icons.apps_rounded),
      (code: 'MOL', label: 'Mol', icon: Icons.agriculture_outlined),
      (code: 'QOY', label: "Qo'y", icon: Icons.cruelty_free_outlined),
      (code: 'ECHKI', label: 'Echki', icon: Icons.pets_outlined),
      (code: 'OT', label: 'Ot', icon: Icons.directions_bike_outlined),
    ];

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(qassobsListProvider);
        ref.invalidate(slaughterhouseListProvider);
      },
      child: ListView(
        // BouncingScrollPhysics — iOS-style rubber-band overscroll on Android too. Premium feel
        // that buyers expect from modern apps.
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: EdgeInsets.zero,
        children: [
          // ---- Hero header — pushes the filter row down ~80pt and gives the screen a clear
          // visual identity instead of the previous "chips slammed against the status bar" feel.
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [cs.primary.withValues(alpha: 0.10), cs.primary.withValues(alpha: 0.04)])),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.location_on_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 6),
                Text('Toshkent',
                    style: tt.bodyMedium?.copyWith(color: cs.primary,
                        fontWeight: FontWeight.w800, letterSpacing: 0.3)),
              ]),
              const SizedBox(height: 6),
              Text("Sizga yaqin qassoblar",
                  style: tt.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900, height: 1.15, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Text("To'g'ridan-to'g'ri bog'laning, narxlarni ko'ring, buyurtma bering",
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            ])),
          const SizedBox(height: 16),
          // ---- Filter row — pill chips with icons. Lower position + clearer affordance.
          SizedBox(height: 44, child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filterRow.length,
            separatorBuilder: (ctx, i) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final f = filterRow[i];
              final on = f.code == filter;
              return _FilterPill(label: f.label, icon: f.icon, selected: on,
                  onTap: () => ref.read(servicesAnimalFilterProvider.notifier).state = f.code);
            })),
          const SizedBox(height: 20),
          // ---- Section A — Qassoblar
          _SectionHeader(label: t.servicesQassobs, count: all.maybeWhen(
              data: (rows) => rows.length, orElse: () => null)),
          _Carousel(async: all),
          const SizedBox(height: 24),
          // ---- Section B — Qushxona xizmatlari
          _SectionHeader(label: t.servicesSlaughterhouses, count: slaughter.maybeWhen(
              data: (rows) => rows.length, orElse: () => null)),
          _Carousel(async: slaughter),
          const SizedBox(height: 24),
        ]),
    );
  }
}


/// Pill-style filter chip with icon + label. Tappable area is generous (full pill) and the selected
/// state uses the brand primary so the active filter pops visually.
class _FilterPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _FilterPill({required this.label, required this.icon, required this.selected,
                      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180), curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
            color: selected ? cs.primary : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? cs.primary : cs.outlineVariant)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: selected ? cs.onPrimary : cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
              fontWeight: FontWeight.w700, fontSize: 13,
              color: selected ? cs.onPrimary : cs.onSurface)),
        ])));
  }
}


/// Section header with the title + an optional count badge — useful when the buyer wants to know
/// how many results landed in this section vs the other.
class _SectionHeader extends StatelessWidget {
  final String label;
  final int? count;
  const _SectionHeader({required this.label, this.count});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(children: [
        Text(label, style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w900,
            letterSpacing: -0.3)),
        const SizedBox(width: 8),
        if (count != null) Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999)),
          child: Text('$count', style: tt.labelMedium?.copyWith(
              color: cs.primary, fontWeight: FontWeight.w800))),
      ]));
  }
}


class _Carousel extends StatelessWidget {
  final AsyncValue<List<Qassob>> async;
  const _Carousel({required this.async});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    // v3.9.11 — was 280 (assumed every card would render specialty chips). When a qassob hasn't set
    // specialties yet the card only needs ~220pt, leaving a wide white void at the bottom that
    // makes the whole carousel look broken. 232 fits both states cleanly: no wasted space for empty
    // profiles, one-line specialty chips still fit for populated ones.
    return SizedBox(height: 232, child: async.when(
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (e, _) => Center(child: Text(e.toString(), style: TextStyle(color: cs.error))),
      data: (rows) {
        if (rows.isEmpty) {
          // Centered empty state with icon — better than a bare line of text. Conveys the absence
          // visually so the buyer scrolls past instead of wondering if it's loading.
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.storefront_outlined, color: cs.onSurfaceVariant, size: 48),
            const SizedBox(height: 8),
            Text(t.servicesNoneFound,
                style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
          ]));
        }
        return ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: rows.length,
          separatorBuilder: (ctx, i) => const SizedBox(width: 12),
          itemBuilder: (_, i) => _QassobCard(q: rows[i]));
      },
    ));
  }
}


/// Refreshed qassob card — taller, photo-forward, overlay status badge + specialty preview chips.
/// Tap navigates to the full detail page (Phase 5).
class _QassobCard extends StatelessWidget {
  final Qassob q;
  const _QassobCard({required this.q});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => context.push('/servislar/${q.id}'),
      borderRadius: BorderRadius.circular(20),
      child: Container(width: 260,
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.outlineVariant),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12, offset: const Offset(0, 4))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ---- Photo with overlay status badge
          Stack(children: [
            SizedBox(width: double.infinity, height: 140,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: q.photoUrl.isNotEmpty
                    ? Image.network(q.photoUrl, fit: BoxFit.cover,
                        errorBuilder: (a, b, c) => Container(color: cs.surfaceContainerLowest,
                            child: Icon(Icons.store_rounded,
                                color: cs.onSurfaceVariant, size: 40)))
                    : Container(color: cs.surfaceContainerLowest,
                        child: Icon(Icons.store_rounded,
                            color: cs.onSurfaceVariant, size: 48)))),
            Positioned(top: 10, left: 10,
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: q.isOpenNow ? const Color(0xCC1B5E20) : const Color(0xCCB71C1C),
                    borderRadius: BorderRadius.circular(999)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 6, height: 6,
                    decoration: const BoxDecoration(color: Colors.white,
                        shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(q.isOpenNow ? "Hozir ochiq" : "Hozir yopiq",
                      style: tt.labelSmall?.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w800,
                          letterSpacing: 0.3)),
                ]))),
            if (q.distanceKm != null)
              Positioned(top: 10, right: 10,
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xCC000000),
                      borderRadius: BorderRadius.circular(999)),
                  child: Text('${q.distanceKm!.toStringAsFixed(1)} km',
                      style: tt.labelSmall?.copyWith(color: Colors.white,
                          fontWeight: FontWeight.w800)))),
          ]),
          // ---- Info block
          Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(q.fullName, style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900, letterSpacing: -0.2),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.star_rounded, size: 14, color: const Color(0xFFEF9A00)),
                const SizedBox(width: 2),
                Text(q.ratingCount > 0 ? q.ratingAvg.toStringAsFixed(1) : '—',
                    style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w800)),
                if (q.ratingCount > 0) Text(' (${q.ratingCount})',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                if (q.yearsExperience > 0) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.workspace_premium_outlined,
                      size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 2),
                  Text(t.servicesYearsExp(q.yearsExperience),
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ]),
              const SizedBox(height: 8),
              // Specialty preview — first 2 chips. Click-through still opens the detail page; the
              // chips are decorative summary, not a separate filter.
              if (q.specialties.isNotEmpty)
                SizedBox(height: 22,
                  child: ListView.separated(scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: q.specialties.length.clamp(0, 2),
                    separatorBuilder: (ctx, i) => const SizedBox(width: 4),
                    itemBuilder: (_, i) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999)),
                      child: Text(q.specialties[i],
                          style: tt.labelSmall?.copyWith(
                              color: cs.primary, fontWeight: FontWeight.w700))))),
            ])),
        ])));
  }
}
