// CartFloatingBar — persistent cart pill above the bottom NavigationBar. Two affordances stacked:
//   • Small centered "Hammasi ^" chip — opens CartPeekSheet (inline cart review).
//   • Main pill — tap → switches to Savat tab.
//
// Implementation notes from the bug-fix pass:
//   • Chip uses GestureDetector + Container (NOT Material + InkWell). The Material+InkWell pattern leaked layout
//     constraints into the chip's row when nested inside the Scaffold's bottomNavigationBar slot, and the failure
//     cascaded into the modal sheet's render tree — that's where the "RenderBox was not laid out" errors came from.
//   • CartPeekSheet body uses a plain Column (not ListView.separated + shrinkWrap + ConstrainedBox). Our peek shows
//     at most ~10 items; the column lays out deterministically. ListView only buys us virtualization we don't need.
//   • Steppers use InkResponse-wrapped icons instead of IconButton.compact — the latter brings _RenderInputPadding
//     that interacts badly with a Column-inside-Column-inside-bottom-sheet tree.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/format.dart';
import '../providers/cart_providers.dart';


/// Drop-in: place above NavigationBar inside MainShell. `onNavigateToCart` flips to the Savat tab.
class CartFloatingBar extends ConsumerWidget {
  final VoidCallback onNavigateToCart;
  const CartFloatingBar({super.key, required this.onNavigateToCart});

  /// Opens the peek sheet from the chip. Uses the root navigator so the sheet floats above the tab bar cleanly.
  void _openPeek(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CartPeekSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final cart = ref.watch(cartProvider);
    if (cart.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Floating bar is intentionally compact + centered. Wider side margins (60pt) keep it visually a "pill", not a
    // full-width toolbar. Pill body shows two stacked lines (SAVAT / Nta) and never a price — the total lives in
    // the opened peek sheet where it has room to breathe.
    return Padding(padding: const EdgeInsets.fromLTRB(60, 2, 60, 6),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // ---------- "Hammasi ^" chip ----------
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openPeek(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5), width: 0.5)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(t.cartPeekChip,
                style: tt.labelSmall?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w700)),
              const SizedBox(width: 3),
              Icon(Icons.keyboard_arrow_up_rounded, size: 16, color: cs.onSurfaceVariant),
            ]),
          ),
        ),

        // ---------- Main pill ----------
        // Two stacked lines on the left: "SAVAT" (bold, full-strength) over "N ta" (lighter, demoted alpha).
        // Chevron on the right. No price — ever — keeps the pill calm; the total is one tap away in the peek sheet.
        Material(color: cs.primary, borderRadius: BorderRadius.circular(14),
          child: InkWell(borderRadius: BorderRadius.circular(14),
            onTap: () { HapticFeedback.lightImpact(); onNavigateToCart(); },
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              // Row sizes to content (no Expanded eating the remaining width) — the chevron now sits next to the
              // text with only a small fixed gap, instead of being pushed to the far right of the pill.
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(t.cartTitle.toUpperCase(),
                    style: tt.titleSmall?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w600,
                        letterSpacing: 1.0, height: 1.0, fontSize: 12)),
                  Text(t.cartItemsShort(cart.itemCount),
                    style: tt.bodySmall?.copyWith(color: cs.onPrimary.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500, height: 1.1, fontSize: 11)),
                ]),
                const SizedBox(width: 50),
                Icon(Icons.chevron_right_rounded, color: cs.onPrimary, size: 22),
              ]))))
      ]));
  }
}


// ---------- Peek sheet ----------

/// Inline cart preview opened from the "Hammasi ^" chip. Single column layout — no ListView (the cart never has
/// more than ~10 unique products, and avoiding ListView removes the shrinkWrap/Column nesting that was crashing
/// layout).
class CartPeekSheet extends ConsumerWidget {
  const CartPeekSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final cart = ref.watch(cartProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final items = cart.items.values.toList();

    return Container(
      decoration: BoxDecoration(color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22))),
      child: SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Centered X close button — pill-shaped tap target. Replaces the drag-handle so the dismiss affordance is
          // explicit + accessible. Sheet remains swipe-dismissible too.
          Padding(padding: const EdgeInsets.only(top: 10, bottom: 14),
            child: Center(child: Material(
              color: cs.surfaceContainerHighest,
              shape: const CircleBorder(),
              child: InkResponse(
                onTap: () => Navigator.pop(context),
                radius: 24,
                child: Padding(padding: const EdgeInsets.all(8),
                  child: Icon(Icons.close_rounded, size: 22, color: cs.onSurface))),
            ))),

          // Header: "Sizning savatingiz (N)" on the left, total on the right.
          // Title carries the inline (N) so users see the cart count and don't need to scan a separate badge.
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: Text('${t.cartPeekTitle} (${cart.itemCount})',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
            Text('${formatSoum(cart.totalSoum)} ${t.soumSuffix}',
              style: tt.titleMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 14),
          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 4),

          // Item rows — bounded scroll. CRITICAL: the inner Column needs `mainAxisSize: MainAxisSize.min`. Without it,
          // the Column inherits MainAxisSize.max and tries to consume the SingleChildScrollView's unbounded vertical
          // axis → cascading "RenderBox was not laid out" errors that bubble all the way to the modal barrier.
          // (Confirmed via Flutter docs: SingleChildScrollView gives its child unbounded constraints along the scroll
          // axis; a default Column there is always an error.)
          ConstrainedBox(constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),
                _PeekRow(item: items[i]),
              ],
            ]))),

          const SizedBox(height: 18),

          // Footer: single full-width CTA — total is already in the sheet's header. Keeping the button on its own
          // line avoids the brittle Row(Expanded + FilledButton.icon) sizing dance.
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50),
                backgroundColor: cs.primary, foregroundColor: cs.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);   // dismiss sheet first so it doesn't linger over the destination tab
              context.go('/savat');     // /savat is the Savat tab branch root — opens the full cart screen
            },
            child: Text(t.cartPeekViewAll,
              style: tt.titleMedium?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w700))),
        ]))));
  }
}


/// One row inside the peek sheet — thumbnail + name + price + qty stepper.
class _PeekRow extends ConsumerWidget {
  final CartItem item;
  const _PeekRow({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final p = item.product;

    return Padding(padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(color: Color(p.accentArgb), borderRadius: BorderRadius.circular(10)),
          child: Icon(p.icon, size: 22, color: Colors.brown.shade700)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(p.displayName(Localizations.localeOf(context).languageCode),
            style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text('${formatSoum(p.priceSoum)} ${t.soumSuffix}${t.perKgShort}',
            style: tt.bodySmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w700)),
        ])),
        // Compact stepper — InkResponse over an Icon, no IconButton (avoids the _RenderInputPadding sizing chain
        // that triggered the original layout exception).
        _PeekStepper(
          qty: item.qty,
          onDec: () => ref.read(cartProvider.notifier).setQty(p.id, item.qty - 1),
          onInc: () => ref.read(cartProvider.notifier).setQty(p.id, item.qty + 1)),
      ]));
  }
}


class _PeekStepper extends StatelessWidget {
  final int qty;
  final VoidCallback onDec, onInc;
  const _PeekStepper({required this.qty, required this.onDec, required this.onInc});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _StepIcon(icon: Icons.remove_circle_outline, color: cs.primary,
        onTap: () { HapticFeedback.selectionClick(); onDec(); }),
      SizedBox(width: 24, child: Center(child: Text('$qty',
        style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)))),
      _StepIcon(icon: Icons.add_circle_outline, color: cs.primary,
        onTap: () { HapticFeedback.selectionClick(); onInc(); }),
    ]);
  }
}


/// Plain icon + tap target — InkResponse wraps a 28×28 Icon. No Material ancestor required.
class _StepIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _StepIcon({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkResponse(onTap: onTap, radius: 22,
      child: Padding(padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 22, color: color)));
  }
}
