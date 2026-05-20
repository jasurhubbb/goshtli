// CartScreen — the "Savat" tab. Built around the reference design: back arrow + title + item count, scrollable list
// of product cards with qty steppers, "Do'konga izoh" composer pinned below, and a sticky total + checkout CTA at
// the bottom. Empty state owns the whole viewport so it doesn't feel like a hollow form.
//
// Apple-style polish applied throughout: filled-tonal buttons for the stepper, hairline dividers, generous
// whitespace, brand-coloured prices, single-action bottom bar so the primary CTA is always thumb-reachable.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/format.dart' show formatSoum;
import '../providers/cart_providers.dart';


class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final cart = ref.watch(cartProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        // Circular back-icon button matches the reference's pill-style chevron at the top-left. The cart lives inside
        // a tab branch — there's no router back stack to pop, so we just hop back to the Menyu tab.
        leading: Padding(padding: const EdgeInsets.only(left: 12),
          child: IconButton.filledTonal(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => context.go('/'))),
        leadingWidth: 56,
        title: Text(t.cartTitle, style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        centerTitle: false,
        elevation: 0,
        backgroundColor: cs.surface,
        actions: [
          Padding(padding: const EdgeInsets.only(right: 20), child: Center(
            child: Text(t.cartItemsCount(cart.itemCount),
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)))),
        ],
      ),
      body: cart.isEmpty ? const _EmptyCart() : _CartContent(),
    );
  }
}


// ---------- Empty state ----------

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(child: Padding(padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Iconography stand-in — a soft circular badge with the cart icon, brand-tinted background
        Container(width: 96, height: 96,
          decoration: BoxDecoration(shape: BoxShape.circle, color: cs.primaryContainer.withValues(alpha: 0.4)),
          child: Icon(Icons.shopping_basket_outlined, size: 44, color: cs.primary)),
        const SizedBox(height: 20),
        Text(t.cartEmptyTitle, style: tt.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(t.cartEmptyHint, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          textAlign: TextAlign.center),
        const SizedBox(height: 24),
        FilledButton.icon(
          icon: const Icon(Icons.menu_book_outlined),
          label: Text(t.cartGoToMenu),
          onPressed: () => context.go('/')),
      ])));
  }
}


// ---------- Cart with items ----------

class _CartContent extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CartContent> createState() => _CartContentState();
}


class _CartContentState extends ConsumerState<_CartContent> {
  // Local controller — we mirror the persisted shop-note into it on first build, then push changes back to the
  // notifier on every keystroke. Keeping it in local state avoids cursor jumps on rebuild.
  late final TextEditingController _noteCtl;

  @override
  void initState() {
    super.initState();
    _noteCtl = TextEditingController(text: ref.read(cartProvider).shopNote);
    _noteCtl.addListener(() => ref.read(cartProvider.notifier).setShopNote(_noteCtl.text));
  }

  @override
  void dispose() { _noteCtl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cart = ref.watch(cartProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final items = cart.items.values.toList();

    return Column(children: [
      Expanded(child: CustomScrollView(slivers: [
        // ---------- Product rows ----------
        SliverPadding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          sliver: SliverList.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _CartRow(item: items[i]))),

        // ---------- Shop note (Do'konga izoh) ----------
        SliverPadding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          sliver: SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(t.cartShopNoteLabel, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
            // Filled-tonal text field — soft container, no harsh border, multiline. Apple-style "Notes" inspiration.
            Container(decoration: BoxDecoration(
                color: cs.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4), width: 0.5)),
              child: TextField(
                controller: _noteCtl,
                maxLines: 3, minLines: 3,
                textInputAction: TextInputAction.done,
                style: tt.bodyMedium,
                decoration: InputDecoration(
                  hintText: t.cartShopNoteHint,
                  hintStyle: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
                  contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  border: InputBorder.none,
                ))),
          ]))),

        // ---------- Totals (subtotal + grand total) ----------
        SliverPadding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          sliver: SliverToBoxAdapter(child: Column(children: [
            _TotalRow(label: t.cartSubTotal, value: cart.totalSoum, isPrimary: false),
            const SizedBox(height: 8),
            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            _TotalRow(label: t.cartTotal, value: cart.totalSoum, isPrimary: true),
          ]))),

        // Bottom spacer so the sticky button doesn't crop the last row when scrolled to end
        const SliverToBoxAdapter(child: SizedBox(height: 88)),
      ])),

      // ---------- Sticky checkout bar ----------
      Container(decoration: BoxDecoration(color: cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)))),
        child: SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: SizedBox(width: double.infinity, height: 54, child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: cs.primary, foregroundColor: cs.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            onPressed: () {
              HapticFeedback.mediumImpact();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.cartCheckoutSnack)));
            },
            child: Text(t.cartCheckout,
              style: tt.titleMedium?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w600)))))))
    ]);
  }
}


// ---------- Cart row card ----------

/// One product line — thumbnail tile + name/price + qty stepper. Matches the reference design with the brand-coloured
/// price; star rating is intentionally omitted per the user's design spec.
class _CartRow extends ConsumerWidget {
  final CartItem item;
  const _CartRow({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final p = item.product;

    return Container(padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4), width: 0.5)),
      child: Row(children: [
        // Thumbnail — coloured square with the product's icon. Will become Image.network when real listings land.
        Container(width: 72, height: 72,
          decoration: BoxDecoration(color: Color(p.accentArgb), borderRadius: BorderRadius.circular(14)),
          child: Icon(p.icon, size: 36, color: Colors.brown.shade700)),
        const SizedBox(width: 12),

        // Name (up to 2 lines, smaller weight than headline) + price in brand colour
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(p.displayName(Localizations.localeOf(context).languageCode),
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Text('${formatSoum(p.priceSoum)} ${t.soumSuffix}${t.perKgShort}',
              style: tt.titleMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w700)),
        ])),
        const SizedBox(width: 8),

        // Qty stepper — minus / readout / plus, capsule-shaped. Tapping below 1 removes the row.
        _QtyStepper(
          qty: item.qty,
          onDec: () => ref.read(cartProvider.notifier).setQty(p.id, item.qty - 1),
          onInc: () => ref.read(cartProvider.notifier).setQty(p.id, item.qty + 1)),
      ]));
  }
}


/// Capsule qty stepper — used on the cart row AND in the peek sheet. Two icon buttons flanking a fixed-width readout
/// keeps the layout stable across qty digits (1 vs. 99).
class _QtyStepper extends StatelessWidget {
  final int qty;
  final VoidCallback onDec;
  final VoidCallback onInc;
  const _QtyStepper({required this.qty, required this.onDec, required this.onInc});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6), width: 1)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _StepperButton(icon: Icons.remove, onTap: () { HapticFeedback.selectionClick(); onDec(); }),
        SizedBox(width: 28, child: Center(
          child: Text('$qty', style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)))),
        _StepperButton(icon: Icons.add, onTap: () { HapticFeedback.selectionClick(); onInc(); }),
      ]));
  }
}


class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkResponse(onTap: onTap, radius: 22,
      child: Padding(padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 18, color: cs.primary)));
  }
}


/// Total row — label on the left, formatted so'm amount on the right. `isPrimary` bumps weight + size for the grand
/// total so it visually dominates the subtotal.
class _TotalRow extends StatelessWidget {
  final String label;
  final int value;
  final bool isPrimary;
  const _TotalRow({required this.label, required this.value, required this.isPrimary});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final labelStyle = isPrimary
        ? tt.titleMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.5)
        : tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant);
    final valueStyle = isPrimary
        ? tt.titleLarge?.copyWith(color: cs.primary, fontWeight: FontWeight.w800)
        : tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600);
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: labelStyle),
      Text('${formatSoum(value)} ${t.soumSuffix}', style: valueStyle),
    ]);
  }
}
