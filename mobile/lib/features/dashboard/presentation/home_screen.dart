// HomeScreen (Menyu tab) — v3.1 product-grid redesign.
//
// What you see: brand-tinted hero (small, just a greeting + "Bugun nima pishirasiz?" hint), then a 2-column grid of
// 10 fake products with brand-coloured prices and inline add/qty controls. Tapping the (+) on a card adds qty 1 to
// the cart; once a product is in the cart, the card's CTA flips into a qty stepper that mirrors the cart state.
//
// All product data is sourced from `fake_products.dart` — when the real /listings API lands, swap the
// fakeProductsProvider for the listings provider and the rest of this screen stays the same.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/format.dart';
import '../../../shared/widgets/language_picker.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/providers/auth_state.dart';
import '../../cart/data/fake_products.dart';
import '../../cart/providers/cart_providers.dart';


class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final auth = ref.watch(authNotifierProvider);
    final products = ref.watch(fakeProductsProvider);
    final greetingName = auth is AuthAuthenticated ? auth.user.fullName : '';

    return Scaffold(
      body: CustomScrollView(slivers: [
        // Compact app bar — keeps the focus on products below
        SliverAppBar(
          title: Text(t.menuTitle, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          floating: true, snap: true,
          actions: const [LanguagePicker(), SizedBox(width: 8)],
        ),
        SliverPadding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          sliver: SliverList.list(children: [
            // Greeting (auth users) OR welcome card (anonymous) — same gradient treatment as before
            if (greetingName.isNotEmpty) _GreetingCard(name: greetingName)
            else const _AnonymousWelcome(),
            const SizedBox(height: 18),
            // Section label — "Pick what you'll cook today" style hint
            Padding(padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(t.menuPickHint, style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700))),
          ])),

        // Product grid — 2 columns with a 0.72 aspect ratio (taller than square) to fit photo + name + price + cta
        SliverPadding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 0.72),
            delegate: SliverChildBuilderDelegate(
              (_, i) => _ProductCard(product: products[i]),
              childCount: products.length))),
      ]),
    );
  }
}


// ---------- Greeting / welcome cards (same gradient treatment as before, lighter text now) ----------

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

/// One product tile — photo region on top, name + price + add/qty CTA on the bottom. The CTA flips from "+" pill to
/// a stepper as soon as the product is in the cart, mirroring how Instamart's product cards behave.
class _ProductCard extends ConsumerWidget {
  final FakeProduct product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    // Only watch the row this card cares about — keeps grid rebuilds local when a single product's qty changes
    final qty = ref.watch(cartProvider.select((s) => s.items[product.id]?.qty ?? 0));

    return Container(
      decoration: BoxDecoration(color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4), width: 0.5)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Image region — coloured background + product icon. Will become Image.network with a fallback later.
        Expanded(child: Container(color: Color(product.accentArgb),
          child: Center(child: Icon(product.icon, size: 64, color: Colors.brown.shade700)))),

        // Info region — name + price + add CTA
        Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(product.displayName(Localizations.localeOf(context).languageCode),
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Row(children: [
              // Price: brand-coloured, bold; "/kg" suffix demoted to a lighter weight beside it
              Expanded(child: RichText(text: TextSpan(
                style: tt.titleSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w800),
                children: [
                  TextSpan(text: '${formatSoum(product.priceSoum)} ${t.soumSuffix}'),
                  TextSpan(text: t.perKgShort,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ]))),
              const SizedBox(width: 6),
              // CTA: + pill before any qty; stepper once the product is in the cart
              qty == 0
                  ? _AddPill(onTap: () { HapticFeedback.lightImpact(); ref.read(cartProvider.notifier).add(product); })
                  : _CardStepper(qty: qty,
                      onDec: () => ref.read(cartProvider.notifier).setQty(product.id, qty - 1),
                      onInc: () => ref.read(cartProvider.notifier).setQty(product.id, qty + 1)),
            ]),
          ])),
      ]));
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
    // Inline stepper — minus / qty / plus, capsule-shaped, sized to fit the card's tight footer.
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
