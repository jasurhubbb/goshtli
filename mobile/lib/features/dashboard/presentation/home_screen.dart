// HomeScreen (Menyu tab) — v3.1 catalog: 2-column product grid fed by the real /api/v1/listings/ endpoint.
//
// Each card shows the product photo (or category icon fallback), bilingual name, brand-coloured price/kg, and a
// + button that flips into an inline qty stepper once the product is in the cart. Tapping the card body drills
// into the listing detail screen via /listings/<id>.
//
// Catalog data comes from activeListingsProvider — backend serves ACTIVE-only by default; pull-to-refresh
// invalidates the provider so workers see new products without restarting the app.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/models/listing.dart';
import '../../../shared/utils/format.dart';
import '../../../shared/widgets/language_picker.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/providers/auth_state.dart';
import '../../cart/providers/cart_providers.dart';
import '../../listings/providers/listings_providers.dart';


class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final auth = ref.watch(authNotifierProvider);
    final async = ref.watch(activeListingsProvider);
    final greetingName = auth is AuthAuthenticated ? auth.user.fullName : '';

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(activeListingsProvider),
        child: CustomScrollView(slivers: [
          SliverAppBar(
            title: Text(t.menuTitle, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            floating: true, snap: true,
            actions: const [LanguagePicker(), SizedBox(width: 8)],
          ),

          // Hero strip — greeting OR anonymous welcome, plus the "pick what you'll cook" section header
          SliverPadding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            sliver: SliverList.list(children: [
              if (greetingName.isNotEmpty) _GreetingCard(name: greetingName) else const _AnonymousWelcome(),
              const SizedBox(height: 18),
              Padding(padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Text(t.menuPickHint, style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700))),
            ])),

          // Product grid — three states (loading / error / data) all rendered as slivers so the scroll view
          // stays a single CustomScrollView (better pull-to-refresh interaction than two stacked widgets).
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
        ]),
      ),
    );
  }
}


// ---------- Greeting / welcome cards ----------

class _GreetingCard extends StatelessWidget {
  final String name;
  const _GreetingCard({required this.name});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final t = AppLocalizations.of(context);
    return Container(padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [cs.primaryContainer.withValues(alpha: 0.7), cs.tertiaryContainer.withValues(alpha: 0.5)])),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t.greeting(name), style: tt.titleMedium?.copyWith(color: cs.onPrimaryContainer)),
      ]));
  }
}


class _AnonymousWelcome extends StatelessWidget {
  const _AnonymousWelcome();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [cs.primaryContainer.withValues(alpha: 0.7), cs.tertiaryContainer.withValues(alpha: 0.5)])),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(t.anonWelcomeTitle, style: tt.titleMedium?.copyWith(
              color: cs.onPrimaryContainer, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(t.anonWelcomeSubtitle,
               style: tt.bodySmall?.copyWith(color: cs.onPrimaryContainer.withValues(alpha: 0.85))),
        ])),
        const SizedBox(width: 12),
        TextButton(onPressed: () => context.push('/register'),
          child: Text(t.signIn, style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w700))),
      ]));
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
          Expanded(child: Container(color: cs.surfaceContainerHighest,
            child: listing.primaryPhotoUrl != null
                ? Image.network(listing.primaryPhotoUrl!, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Center(child: Icon(Icons.image_outlined, size: 56, color: cs.onSurfaceVariant)))
                : Center(child: Icon(Icons.restaurant_outlined, size: 56, color: cs.onSurfaceVariant)))),

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
                        onDec: () => ref.read(cartProvider.notifier).setQty(listing.id, qty - 1),
                        onInc: () => ref.read(cartProvider.notifier).setQty(listing.id, qty + 1)),
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
  const _CardStepper({required this.qty, required this.onDec, required this.onInc});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _Step(icon: Icons.remove, onTap: () { HapticFeedback.selectionClick(); onDec(); }, fg: cs.onPrimary),
        SizedBox(width: 22, child: Center(child: Text('$qty',
          style: tt.bodyMedium?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w800)))),
        _Step(icon: Icons.add, onTap: () { HapticFeedback.selectionClick(); onInc(); }, fg: cs.onPrimary),
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
