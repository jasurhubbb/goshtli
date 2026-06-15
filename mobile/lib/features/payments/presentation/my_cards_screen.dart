// MyCardsScreen — "Mening kartalarim" section reachable from Profile.
//
// Layout: list of saved cards (default badge on the active one) + a sticky "Yangi karta qo'shish" CTA at
// the bottom. Tapping a card opens its action sheet (Set as default / Delete). Empty state has a soft
// illustration + the same CTA centered.
//
// Mirrors the Wolt UZ / Uzum cards screen so the UX is familiar — same chrome, same tap targets.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../data/card_model.dart';
import '../providers/cards_providers.dart';
import 'add_card_sheet.dart';


class MyCardsScreen extends ConsumerWidget {
  const MyCardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final cardsAsync = ref.watch(cardsProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        leading: Padding(padding: const EdgeInsets.only(left: 12),
          child: IconButton.filledTonal(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => context.pop())),
        leadingWidth: 56,
        title: Text(t.cardsTitle, style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        centerTitle: false,
        elevation: 0,
        backgroundColor: cs.surface,
      ),
      body: SafeArea(child: cardsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(padding: const EdgeInsets.all(24),
            child: Center(child: Text(t.cardsLoadError,
                style: tt.bodyMedium?.copyWith(color: cs.error)))),
        data: (cards) => cards.isEmpty
            ? _EmptyState(onAdd: () => _addCard(context, ref))
            : Column(children: [
                Expanded(child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  itemCount: cards.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _CardRow(
                    card: cards[i],
                    onTap: () => _openActions(context, ref, cards[i])),
                )),
                _AddCardBar(onAdd: () => _addCard(context, ref)),
              ]),
      ))
    );
  }

  Future<void> _addCard(BuildContext context, WidgetRef ref) async {
    // First-card add auto-defaults via the backend even when the toggle is off — the model enforces it.
    // We still pre-select "make default" when the list is currently empty so the toggle reflects reality.
    final hasNone = (ref.read(cardsProvider).value ?? const []).isEmpty;
    await showAddCardSheet(context, autoMakeDefault: hasNone);
  }

  Future<void> _openActions(BuildContext context, WidgetRef ref, PaymentCard card) async {
    final t = AppLocalizations.of(context);
    HapticFeedback.selectionClick();
    final notifier = ref.read(cardsProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final res = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Container(width: 40, height: 4,
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 14),
        if (!card.isDefault)
          ListTile(leading: const Icon(Icons.star_rounded),
              title: Text(t.cardsActionMakeDefault),
              onTap: () => Navigator.pop(context, 'default')),
        ListTile(leading: Icon(Icons.delete_outline_rounded,
                color: Theme.of(context).colorScheme.error),
            title: Text(t.cardsActionDelete,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () => Navigator.pop(context, 'delete')),
        const SizedBox(height: 4),
      ])),
    );
    if (res == 'default') {
      try {
        await notifier.setDefault(card.id);
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } else if (res == 'delete') {
      try {
        await notifier.delete(card.id);
        messenger.showSnackBar(SnackBar(content: Text(t.cardsDeletedSnack)));
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}


// ---------- Empty state ----------

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(child: Padding(padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 96, height: 96,
          decoration: BoxDecoration(shape: BoxShape.circle,
              color: cs.primaryContainer.withValues(alpha: 0.5)),
          child: Icon(Icons.credit_card_rounded, size: 44, color: cs.primary)),
        const SizedBox(height: 22),
        Text(t.cardsEmptyTitle, style: tt.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(t.cardsEmptyHint,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant), textAlign: TextAlign.center),
        const SizedBox(height: 26),
        FilledButton.icon(
          icon: const Icon(Icons.add_rounded),
          label: Text(t.cardsAddCta),
          onPressed: onAdd),
      ])));
  }
}


// ---------- One-row card ----------

class _CardRow extends StatelessWidget {
  final PaymentCard card;
  final VoidCallback onTap;
  const _CardRow({required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final dim = card.isExpired;
    return Opacity(opacity: dim ? 0.55 : 1.0,
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16),
        child: Container(padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5))),
          child: Row(children: [
            _BrandIcon(brand: card.brand),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Text(card.maskedDisplay,
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800,
                        letterSpacing: 0.6)),
                if (card.isDefault) ...[
                  const SizedBox(width: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999)),
                    child: Text(t.cardsDefaultBadge,
                        style: tt.labelSmall?.copyWith(color: cs.primary,
                            fontWeight: FontWeight.w800, letterSpacing: 0.4))),
                ],
              ]),
              const SizedBox(height: 4),
              Text(dim ? t.cardsExpiredLabel : '${t.cardsExpiry}: ${card.expiryDisplay}',
                  style: tt.bodySmall?.copyWith(color: dim ? cs.error : cs.onSurfaceVariant)),
            ])),
            Icon(Icons.more_vert_rounded, color: cs.onSurfaceVariant),
          ]))),
    );
  }
}


/// Brand-coloured square icon used in the card row + the picker.
class _BrandIcon extends StatelessWidget {
  final CardBrand brand;
  const _BrandIcon({required this.brand});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (brand) {
      CardBrand.visa => ('VISA', const Color(0xFF1A1F71)),
      CardBrand.mastercard => ('MC', const Color(0xFFEB001B)),
      CardBrand.humo => ('HUMO', const Color(0xFF008080)),
      CardBrand.uzcard => ('UZCARD', const Color(0xFF002F87)),
      CardBrand.unknown => ('CARD', Colors.grey),
    };
    return Container(width: 48, height: 32,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      alignment: Alignment.center,
      child: Text(label, style: const TextStyle(color: Colors.white,
          fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5)));
  }
}


// ---------- Bottom add bar (visible when list is non-empty) ----------

class _AddCardBar extends StatelessWidget {
  final VoidCallback onAdd;
  const _AddCardBar({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(color: cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)))),
      child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: SizedBox(width: double.infinity, height: 54,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            icon: const Icon(Icons.add_rounded),
            label: Text(t.cardsAddCta),
            onPressed: onAdd))),
    );
  }
}
