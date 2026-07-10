// OrderPayScreen — v3.7 in-app PaymentMethodPicker.
//
// Replaces the v3.5 WebView checkout for the common path. The buyer arrives here right after the
// delivery page has placed the order. We show:
//   • The order amount (so the buyer sees what they're about to pay)
//   • A list of saved cards (picker), each tappable. Default card is pre-selected.
//   • Inline "Yangi karta qo'shish" row at the bottom of the list — opens AddCardSheet.
//   • Sticky "To'lash <amount>" CTA at the bottom; disabled until a card is picked.
//
// On tap-pay: hits POST /payments/orders/<id>/pay-with-card/ — mock mode marks the order PAID
// instantly and we navigate to /orders/<id>. Real Payme would inject a 6-digit SMS modal here;
// per current product decision (user said "no real SMS, accept anything") we skip that step
// in mock mode but the picker still has the right hooks to add it later.
//
// Empty-cards state: if the buyer has no cards on entry, we auto-open AddCardSheet immediately
// (inline add-card flow) so they don't have to detour to Profile first.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/format.dart' show formatSoum;
import '../../listings/data/listings_repository.dart' show ApiException;
import '../../orders/providers/orders_providers.dart';
import '../data/card_model.dart';
import '../providers/cards_providers.dart';
import 'add_card_sheet.dart';


class OrderPayScreen extends ConsumerStatefulWidget {
  final int orderId;
  // v3.9.16 — remaining unpaid orders from a multi-item cart. After this order is paid we advance to the
  // next one's pay screen, so every order in a multi-line checkout collects payment (empty = last/only order).
  final List<int> nextOrderIds;
  const OrderPayScreen({super.key, required this.orderId, this.nextOrderIds = const []});
  @override
  ConsumerState<OrderPayScreen> createState() => _OrderPayScreenState();
}


class _OrderPayScreenState extends ConsumerState<OrderPayScreen> {
  int? _selectedCardId;
  bool _paying = false;
  String? _error;
  // The PAID flag flips when the backend confirms; we render the success view from that.
  bool _paid = false;
  String? _paidCardLast4;
  String? _paidCardBrand;

  @override
  void initState() {
    super.initState();
    // Pre-select the default card so the buyer can immediately tap Pay. If the list is empty when it
    // resolves, open the add-card sheet in a post-frame callback — same UX as Wolt's "no card → add".
    Future.microtask(() {
      final list = ref.read(cardsProvider).value;
      if (list != null && list.isEmpty) _openAddSheet();
    });
  }

  void _onCardListResolved(List<PaymentCard> list) {
    if (_selectedCardId != null) return;
    final def = list.where((c) => c.isDefault && !c.isExpired).firstOrNull
                ?? list.where((c) => !c.isExpired).firstOrNull;
    if (def != null) setState(() => _selectedCardId = def.id);
  }

  Future<void> _openAddSheet() async {
    final addedCard = await showAddCardSheet(context,
        autoMakeDefault: (ref.read(cardsProvider).value ?? const []).isEmpty);
    if (addedCard != null && mounted) {
      setState(() => _selectedCardId = addedCard.id);
    }
  }

  /// Order's amount-to-pay. We fetch the order from the orders repo so the picker shows authoritative
  /// data (delivery + butcher already rolled into total_price by the backend).
  Future<({int soum, bool alreadyPaid})> _fetchAmount() async {
    final order = await ref.read(ordersRepositoryProvider).getById(widget.orderId);
    return (soum: order.totalPrice.toInt(), alreadyPaid: order.paymentStatus.name == 'paid');
  }

  Future<void> _pay() async {
    if (_selectedCardId == null) return;
    final t = AppLocalizations.of(context);
    setState(() { _paying = true; _error = null; });
    HapticFeedback.mediumImpact();
    try {
      final res = await ref.read(cardsRepositoryProvider).payWithCard(
          orderId: widget.orderId, cardId: _selectedCardId!);
      if (!mounted) return;
      if (res.paymentStatus == 'PAID') {
        setState(() {
          _paid = true;
          _paidCardLast4 = res.cardLast4;
          _paidCardBrand = res.cardBrand;
        });
        // After a brief visual confirmation: if this was one of several orders from a multi-item cart,
        // advance to the next order's payment; otherwise hop to the order detail screen.
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (!mounted) return;
          if (widget.nextOrderIds.isNotEmpty) {
            context.pushReplacement('/orders/${widget.nextOrderIds.first}/pay',
                extra: {'batch': widget.nextOrderIds.sublist(1)});
          } else {
            context.go('/orders/${widget.orderId}');
          }
        });
      } else {
        setState(() { _paying = false; _error = t.payFailedTitle; });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() { _paying = false; _error = e.message; });
    } catch (e) {
      if (mounted) setState(() { _paying = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final cardsAsync = ref.watch(cardsProvider);
    if (_paid) return _SuccessView(orderId: widget.orderId,
        cardLast4: _paidCardLast4 ?? '', cardBrand: _paidCardBrand ?? 'CARD');

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(title: Text(t.payTitle), elevation: 0,
        leading: Padding(padding: const EdgeInsets.only(left: 12),
          child: IconButton.filledTonal(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => context.pop())),
        leadingWidth: 56),
      body: SafeArea(child: cardsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(padding: const EdgeInsets.all(24),
            child: Center(child: Text(t.cardsLoadError,
                style: TextStyle(color: cs.error)))),
        data: (cards) {
          _onCardListResolved(cards);
          return _PickerBody(
            orderAmountFuture: _fetchAmount(),
            cards: cards,
            selectedCardId: _selectedCardId,
            onPickCard: (id) => setState(() { _selectedCardId = id; _error = null; }),
            onAddCard: _openAddSheet,
            onPay: _pay,
            paying: _paying,
            error: _error,
          );
        },
      )),
    );
  }
}


// ---------- Body ----------

class _PickerBody extends StatelessWidget {
  final Future<({int soum, bool alreadyPaid})> orderAmountFuture;
  final List<PaymentCard> cards;
  final int? selectedCardId;
  final ValueChanged<int> onPickCard;
  final VoidCallback onAddCard;
  final VoidCallback onPay;
  final bool paying;
  final String? error;
  const _PickerBody({required this.orderAmountFuture, required this.cards,
                     required this.selectedCardId, required this.onPickCard,
                     required this.onAddCard, required this.onPay,
                     required this.paying, required this.error});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return FutureBuilder<({int soum, bool alreadyPaid})>(future: orderAmountFuture, builder: (_, snap) {
      final amount = snap.data?.soum ?? 0;
      final amountText = '${formatSoum(amount)} ${t.soumSuffix}';
      return Column(children: [
        // ---- Amount header ----
        Container(width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20)),
          child: Column(children: [
            Text(t.paymentAmountLabel,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 6),
            Text(snap.connectionState == ConnectionState.waiting ? '…' : amountText,
                style: tt.displaySmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w900,
                    letterSpacing: 0.5)),
          ])),

        // ---- Section header for cards list ----
        Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
          child: Row(children: [
            Expanded(child: Text(t.paymentMethodSection,
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800,
                    color: cs.onSurface.withValues(alpha: 0.85)))),
          ])),

        // ---- List of cards + "Add new" tile ----
        Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          children: [
            for (final c in cards) _CardOption(
              card: c,
              selected: c.id == selectedCardId,
              onTap: () { HapticFeedback.selectionClick(); onPickCard(c.id); }),
            const SizedBox(height: 10),
            _AddCardTile(onTap: () { HapticFeedback.selectionClick(); onAddCard(); }),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, textAlign: TextAlign.center,
                  style: tt.bodyMedium?.copyWith(color: cs.error, fontWeight: FontWeight.w700)),
            ],
          ])),

        // ---- Sticky Pay CTA ----
        Container(decoration: BoxDecoration(color: cs.surface,
            border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)))),
          child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: SizedBox(width: double.infinity, height: 54,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: selectedCardId == null ? cs.surfaceContainerHighest : cs.primary,
                    foregroundColor: selectedCardId == null ? cs.onSurfaceVariant : cs.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: (selectedCardId == null || paying) ? null : onPay,
                child: paying
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: Colors.white))
                    : Text(amount > 0 ? t.paymentPayCta(amountText) : t.paymentPayCtaShort,
                        style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)))))),
      ]);
    });
  }
}


// ---------- One card-pick row ----------

class _CardOption extends StatelessWidget {
  final PaymentCard card;
  final bool selected;
  final VoidCallback onTap;
  const _CardOption({required this.card, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final disabled = card.isExpired;
    return Padding(padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(opacity: disabled ? 0.55 : 1.0,
        child: InkWell(onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected ? cs.primaryContainer.withValues(alpha: 0.35) : cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? cs.primary : cs.outlineVariant.withValues(alpha: 0.5),
                width: selected ? 1.8 : 0.8)),
            child: Row(children: [
              _SquareBrandIcon(brand: card.brand),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Text(card.maskedDisplay,
                      style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                  if (card.isDefault) ...[
                    const SizedBox(width: 8),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999)),
                      child: Text(t.cardsDefaultBadge,
                          style: tt.labelSmall?.copyWith(color: cs.primary,
                              fontWeight: FontWeight.w800, letterSpacing: 0.4))),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(disabled ? t.cardsExpiredLabel : card.expiryDisplay,
                    style: tt.labelSmall?.copyWith(color: disabled ? cs.error : cs.onSurfaceVariant)),
              ])),
              Container(width: 22, height: 22,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: selected ? cs.primary : Colors.transparent,
                    border: Border.all(color: selected ? cs.primary : cs.outlineVariant, width: 1.6)),
                child: selected ? Icon(Icons.check_rounded, size: 14, color: cs.onPrimary) : null),
            ])))));
  }
}


/// "Yangi karta qo'shish" tile — always last in the picker, even when there are saved cards.
class _AddCardTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddCardTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16),
      child: Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: cs.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.primary.withValues(alpha: 0.5),
                style: BorderStyle.solid, width: 1.2)),
        child: Row(children: [
          Container(width: 48, height: 32,
            decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6)),
            alignment: Alignment.center,
            child: Icon(Icons.add_rounded, color: cs.primary, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Text(t.cardsAddCta,
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: cs.primary))),
        ])));
  }
}


class _SquareBrandIcon extends StatelessWidget {
  final CardBrand brand;
  const _SquareBrandIcon({required this.brand});

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


// ---------- Success view ----------

class _SuccessView extends StatelessWidget {
  final int orderId;
  final String cardLast4;
  final String cardBrand;
  const _SuccessView({required this.orderId, required this.cardLast4, required this.cardBrand});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(child: Center(child: Padding(padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 96, height: 96,
            decoration: const BoxDecoration(color: Color(0xFF2E7D32), shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 64)),
          const SizedBox(height: 24),
          Text(t.paySuccessTitle, style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(t.paymentSuccessCardLine(cardBrand, cardLast4),
              style: tt.bodyLarge, textAlign: TextAlign.center),
        ])))));
  }
}
