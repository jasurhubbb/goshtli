// DeliveryScreen — the "Yetkazib berish" page per PRD v2 §3.
//
// Slots into the user flow as: Cart → DeliveryScreen → OrderPay → Orders. The screen owns four sections,
// stacked vertically, each rendered as a soft Material card with 16pt padding:
//   1. Address       — active delivery address + "Change" → opens address sheet. Shows "Please set an
//                      address" empty state when none picked. Distance pill renders once the quote
//                      backend returns it.
//   2. Vehicle       — radio cards for Refrigerator + Chorva-Taksi. Greyed out when not eligible (with
//                      the reason from the backend explaining WHY).
//   3. Time slot     — 3 chip-style buttons for 06-09 / 09-13 / 13-18. Lone-selection group.
//   4. Butcher       — only shown when cart has at least one live animal. A switch tile that re-quotes
//                      the backend on toggle (because flipping it changes which vehicle is eligible).
//   5. Price breakdown — Products + Delivery + Butcher = TOTAL, shown above the sticky CTA.
//
// The sticky bottom CTA "To'lovga o'tish" places ALL cart orders (one per line) with the chosen delivery
// params, then pushes /orders/<id>/pay for single-order carts, or /orders for multi.
//
// Design notes (PRD §5 polish): 16pt horizontal padding throughout, soft elevation cards, brand-primary
// accent for the selected radio, brand-error red for the unavailable explanation, generous whitespace
// between sections so each block reads as its own decision.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/format.dart' show formatSoum;
import '../../addresses/presentation/address_sheet.dart';
import '../../addresses/providers/addresses_providers.dart';
import '../../addresses/providers/effective_address_provider.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/providers/auth_state.dart';
import '../../auth/providers/pending_redirect_provider.dart';
import '../../cart/providers/cart_providers.dart';
import '../../listings/data/listings_repository.dart' show ApiException;
import '../../orders/providers/orders_providers.dart';
import '../data/delivery_models.dart';
import '../providers/delivery_providers.dart';


class DeliveryScreen extends ConsumerStatefulWidget {
  const DeliveryScreen({super.key});
  @override
  ConsumerState<DeliveryScreen> createState() => _DeliveryScreenState();
}


class _DeliveryScreenState extends ConsumerState<DeliveryScreen> {
  @override
  void initState() {
    super.initState();
    // Reset any leftover state (vehicle, butcher toggle) from a prior visit. We want this page to feel
    // like a fresh decision each time the buyer reaches it.
    Future.microtask(() {
      ref.read(deliverySelectionProvider.notifier).reset();
      _refreshQuote();
    });
  }

  /// Hit POST /delivery/quote/ with the current cart + effective location + butcher toggle. Called from:
  ///   • initState (first paint)
  ///   • butcher switch toggle (because vehicle eligibility flips)
  ///   • the error-state "retry" button
  ///
  /// We use the unified `effectiveDeliveryLocationProvider` so the page always has coords (Tashkent
  /// center as the absolute fallback). Outside-Tashkent coords are auto-snapped to Tashkent.
  Future<void> _refreshQuote() async {
    final cart = ref.read(cartProvider);
    if (cart.items.isEmpty) return;
    final eff = ref.read(effectiveDeliveryLocationProvider);
    final notifier = ref.read(deliverySelectionProvider.notifier);
    notifier.setLoading(true);
    notifier.setError(null);
    try {
      final quote = await ref.read(deliveryRepositoryProvider).getQuote(
        items: [for (final item in cart.items.values)
          (listingId: item.listing.id, quantityKg: item.qty.toDouble())],
        buyerLat: eff.lat,
        buyerLng: eff.lng,
        butcherServiceRequested: ref.read(deliverySelectionProvider).butcherRequested,
      );
      notifier.setQuote(quote);
    } on ApiException catch (e) {
      notifier.setLoading(false);
      notifier.setError(e.message);
    } catch (e) {
      notifier.setLoading(false);
      // Show the actual diagnostic — the previous "generic only" message hid the real cause (auth
      // timeout, network unreachable, server 500). Buyers tap Retry; we surface the cause so dev mode
      // and the user can both reason about it.
      notifier.setError(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final cart = ref.watch(cartProvider);
    final eff = ref.watch(effectiveDeliveryLocationProvider);
    final selection = ref.watch(deliverySelectionProvider);
    // Re-quote on ANY change to the effective location — covers picking a new saved address, GPS
    // re-resolving (e.g. after the TEST: Yunusobod button), and the address being cleared. Comparing
    // lat/lng tuples avoids re-quoting on cosmetic label changes from reverse-geocoding.
    ref.listen(effectiveDeliveryLocationProvider, (prev, next) {
      if (prev == null) return;
      if (prev.lat != next.lat || prev.lng != next.lng) _refreshQuote();
    });

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        leading: Padding(padding: const EdgeInsets.only(left: 12),
          child: IconButton.filledTonal(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => context.pop())),
        leadingWidth: 56,
        title: Text(t.deliveryTitle,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        centerTitle: false,
        elevation: 0,
        backgroundColor: cs.surface,
      ),
      body: SafeArea(child: Column(children: [
        // PRD §3 service area note — only visible when the user's coords were snapped to Tashkent
        // (i.e. they're outside the bbox). Tells them the quote is for Tashkent, not their real coords.
        if (eff.snappedToTashkent) _TashkentOnlyBanner(),
        Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 16), children: [
          _AddressCard(eff: eff, distanceKm: selection.quote?.distanceKm),
          const SizedBox(height: 16),
          _VehicleSection(quote: selection.quote, selectedCode: selection.vehicleCode,
                          loading: selection.loading, error: selection.error,
                          onRetry: _refreshQuote,
                          onPick: (code) => ref.read(deliverySelectionProvider.notifier).setVehicle(code)),
          const SizedBox(height: 16),
          _TimeSlotSection(quote: selection.quote, selectedCode: selection.timeSlotCode,
                           onPick: (code) => ref.read(deliverySelectionProvider.notifier).setTimeSlot(code)),
          if (selection.quote?.cartHasLiveAnimal ?? false) ...[
            const SizedBox(height: 16),
            _ButcherSection(quote: selection.quote!.butcherService, requested: selection.butcherRequested,
                            onToggle: (v) {
                              ref.read(deliverySelectionProvider.notifier).setButcherRequested(v);
                              _refreshQuote();                                  // re-quote because vehicle eligibility shifts
                            }),
            // v3.9.14 — suggested qassobs strip surfaces when butcher service is requested.
            // v3.9.15 upgrade: tap = pick a specific qassob for this order (sends preferred_qassob
            // on POST /orders/). Second tap on the same card un-picks. Chevron-right icon on each
            // card still opens the full detail page for buyers who want to research first.
            if (selection.butcherRequested) ...[
              const SizedBox(height: 12),
              const _SuggestedQassobsStrip(),
            ],
          ],
          const SizedBox(height: 16),
          _BreakdownCard(
            productsSoum: cart.totalSoum,
            deliverySoum: selection.deliveryPrice.toInt(),
            butcherSoum: selection.butcherFee.toInt(),
          ),
        ])),
        // Sticky CTA — disabled until vehicle + time slot are both picked.
        _CheckoutBar(eff: eff, canProceed: selection.vehicleCode != null
                                  && selection.timeSlotCode != null
                                  && !selection.loading),
      ])),
    );
  }
}


// ---------- Section: Address ----------

class _AddressCard extends StatelessWidget {
  final EffectiveDeliveryLocation eff;
  final double? distanceKm;
  const _AddressCard({required this.eff, this.distanceKm});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    // Resolve the displayable label — the sentinel from the resolver maps to "Mening joylashuvim" so
    // the address row reads naturally even when we're on a raw GPS fix without a saved label.
    final displayLabel = eff.unresolved
        ? t.deliveryNeedAddress
        : (eff.label == kCurrentLocationFallbackLabel
            ? t.addressMapMyLocation
            : (eff.label.isEmpty ? t.deliveryAddressSection : eff.label));
    final displayBody = eff.unresolved
        ? t.deliveryPickMapHint
        : (eff.addressLine.isEmpty ? 'Toshkent' : eff.addressLine);
    return _SectionShell(
      title: t.deliveryAddressSection,
      trailing: TextButton.icon(
        icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
        label: Text(t.deliveryAddressChange),
        onPressed: () => showAddressSheet(context)),
      child: Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.location_on_rounded, color: cs.primary, size: 24)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(displayLabel, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(displayBody, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            if (distanceKm != null) ...[
              const SizedBox(height: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(999)),
                child: Text(t.deliveryDistanceLabel(distanceKm!.toStringAsFixed(1)),
                    style: tt.labelSmall?.copyWith(color: cs.onPrimaryContainer,
                                                    fontWeight: FontWeight.w700))),
            ],
          ])),
        ])),
    );
  }
}


/// Soft amber pill above the page contents — only visible when the buyer's coord was outside Tashkent
/// and we snapped it. Per PRD §3, delivery is Tashkent-only for v1.
class _TashkentOnlyBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Container(width: double.infinity,
      color: const Color(0xFFFFF4E5),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(children: [
        const Icon(Icons.info_outline_rounded, color: Color(0xFF8A4F00), size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(t.deliveryTashkentOnlyBanner,
            style: const TextStyle(color: Color(0xFF8A4F00), fontWeight: FontWeight.w600, fontSize: 13))),
      ]));
  }
}


// ---------- Section: Vehicle ----------

class _VehicleSection extends StatelessWidget {
  final DeliveryQuote? quote;
  final String? selectedCode;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final ValueChanged<String> onPick;
  const _VehicleSection({required this.quote, required this.selectedCode,
                         required this.loading, required this.error,
                         required this.onRetry, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return _SectionShell(
      title: t.deliveryVehicleSection,
      child: Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: loading
            ? const Padding(padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()))
            : error != null
                // Show the localized headline AND the raw diagnostic underneath so dev/users can see
                // what actually went wrong (e.g. "Connection refused", "401 Unauthorized"). Always
                // include a retry button.
                ? Padding(padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(children: [
                      Icon(Icons.cloud_off_rounded, color: cs.error, size: 36),
                      const SizedBox(height: 8),
                      Text(t.deliveryQuoteError, textAlign: TextAlign.center,
                          style: tt.bodyMedium?.copyWith(color: cs.error, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(error!, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis,
                          style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                      const SizedBox(height: 12),
                      FilledButton.tonal(onPressed: onRetry, child: Text(t.payRetry)),
                    ]))
                : quote == null
                    ? const SizedBox.shrink()
                    : Column(children: [
                        for (final opt in quote!.options) ...[
                          _VehicleCard(option: opt, selected: opt.code == selectedCode,
                                       onPick: () => onPick(opt.code)),
                          if (opt != quote!.options.last) const SizedBox(height: 10),
                        ],
                      ])),
    );
  }
}


class _VehicleCard extends StatelessWidget {
  final VehicleOption option;
  final bool selected;
  final VoidCallback onPick;
  const _VehicleCard({required this.option, required this.selected, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final disabled = !option.available;
    final title = option.isRefrigerator ? t.deliveryVehicleRefrigerator : t.deliveryVehicleChorvaTaxi;
    final hint = option.isRefrigerator ? t.deliveryVehicleRefrigeratorHint : t.deliveryVehicleChorvaTaxiHint;
    final iconData = option.isRefrigerator ? Icons.ac_unit_rounded : Icons.pets_rounded;
    return Opacity(opacity: disabled ? 0.55 : 1.0,
      child: InkWell(onTap: disabled ? null : () { HapticFeedback.selectionClick(); onPick(); },
        borderRadius: BorderRadius.circular(16),
        child: Container(padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? cs.primaryContainer.withValues(alpha: 0.35) : cs.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? cs.primary : cs.outlineVariant.withValues(alpha: 0.5),
              width: selected ? 1.6 : 0.8)),
          child: Row(children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(iconData, color: cs.primary)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(disabled ? (option.reasonUnavailable.isNotEmpty ? option.reasonUnavailable : t.deliveryVehicleUnavailable) : hint,
                  style: tt.bodySmall?.copyWith(color: disabled ? cs.error : cs.onSurfaceVariant)),
              const SizedBox(height: 6),
              // Tariff breakdown — base + per-km × distance — surfaces the PRD's pricing formula to the buyer so
              // the line item doesn't feel arbitrary.
              Text('${formatSoum(option.baseFee.toInt())} + ${formatSoum(option.perKmFee.toInt())}/km × ${option.distanceKm.toStringAsFixed(1)} km',
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
            ])),
            const SizedBox(width: 8),
            Text('${formatSoum(option.totalPrice.toInt())} so\'m',
              style: tt.titleSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w800)),
            const SizedBox(width: 6),
            // Selection indicator — the card's border + tint already convey state; this is the small dot
            // accent so the buyer's eye lands on the chosen row even from a glance.
            Container(width: 22, height: 22,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: selected ? cs.primary : Colors.transparent,
                border: Border.all(color: selected ? cs.primary : cs.outlineVariant, width: 1.6)),
              child: selected ? Icon(Icons.check_rounded, size: 14, color: cs.onPrimary) : null),
          ]))));
  }
}


// ---------- Section: Time slot ----------

class _TimeSlotSection extends StatelessWidget {
  final DeliveryQuote? quote;
  final String? selectedCode;
  final ValueChanged<String> onPick;
  const _TimeSlotSection({required this.quote, required this.selectedCode, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final slots = quote?.timeSlots ?? const [];
    return _SectionShell(
      title: t.deliveryTimeSlotSection,
      child: Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Wrap(spacing: 8, runSpacing: 10, children: [
          for (final slot in slots)
            ChoiceChip(
              label: Text(slot.label, style: tt.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: slot.code == selectedCode ? cs.onPrimary : cs.onSurface)),
              selected: slot.code == selectedCode,
              selectedColor: cs.primary,
              onSelected: (_) { HapticFeedback.selectionClick(); onPick(slot.code); },
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999),
                  side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4))),
            ),
        ])),
    );
  }
}


// ---------- Section: Butcher service ----------

class _ButcherSection extends StatelessWidget {
  final ButcherServiceQuote quote;
  final bool requested;
  final ValueChanged<bool> onToggle;
  const _ButcherSection({required this.quote, required this.requested, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return _SectionShell(
      title: t.deliveryButcherSection,
      child: Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(color: const Color(0xFFFFE0B2),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.handyman_rounded, color: Color(0xFF5D3A00))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(t.deliveryButcherTitle, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(t.deliveryButcherSubtitle,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 8),
              Text(t.deliveryButcherFeeLabel('${formatSoum(quote.flatFee.toInt())} so\'m'),
                  style: tt.bodySmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w700)),
            ])),
            Switch(value: requested, onChanged: (v) { HapticFeedback.lightImpact(); onToggle(v); }),
          ]),
        ])),
    );
  }
}


// ---------- Section: Suggested qassobs (v3.9.14) ----------

/// Horizontal carousel of verified qassobs that could handle the live-animal slaughter for this
/// order. Pulled from GET /qassobs/ (defaults to open + verified). Tap → /servislar/<id> full
/// detail. Renders inline under the ButcherSection whenever `butcherRequested` is on.
class _SuggestedQassobsStrip extends ConsumerWidget {
  const _SuggestedQassobsStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final async = ref.watch(_suggestedQassobsProvider);
    final picked = ref.watch(deliverySelectionProvider
        .select((s) => s.preferredQassobId != null));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(children: [
          Icon(Icons.groups_2_rounded, size: 18, color: cs.primary),
          const SizedBox(width: 6),
          Expanded(child: Text("Qassobni tanlang (ixtiyoriy)",
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
          if (picked) TextButton.icon(
              onPressed: () => ref.read(deliverySelectionProvider.notifier)
                  .togglePreferredQassob(
                      ref.read(deliverySelectionProvider).preferredQassobId!),
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text('Bekor',
                  style: TextStyle(fontWeight: FontWeight.w800))),
        ])),
      Padding(padding: const EdgeInsets.only(left: 4, right: 4, bottom: 6),
        child: Text(picked
            ? "Tanlangan qassobga birinchi navbatda taklif yuboriladi"
            : "Ma'lum qassob tanlamasangiz, sistema mos qassobga taklifni yuboradi",
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant))),
      const SizedBox(height: 4),
      SizedBox(height: 120, child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('—',
            style: TextStyle(color: cs.onSurfaceVariant))),
        data: (rows) {
          if (rows.isEmpty) {
            return Center(child: Text("Hozircha qassoblar yo'q",
                style: TextStyle(color: cs.onSurfaceVariant)));
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _SuggestedCard(row: rows[i]));
        },
      )),
    ]);
  }
}


/// Fetches verified qassobs. autoDispose so the list frees when the delivery screen closes.
final _suggestedQassobsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final r = await ref.read(apiClientProvider).dio.get('/qassobs/');
    if (r.data is List) {
      return (r.data as List).cast<Map<String, dynamic>>().take(8).toList();
    }
    if (r.data is Map && r.data['results'] is List) {
      return (r.data['results'] as List).cast<Map<String, dynamic>>().take(8).toList();
    }
  } catch (_) {}
  return const [];
});


class _SuggestedCard extends ConsumerWidget {
  final Map<String, dynamic> row;
  const _SuggestedCard({required this.row});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final id = (row['id'] as num?)?.toInt() ?? 0;
    final name = (row['full_name'] as String?) ?? '—';
    final photoUrl = (row['photo_url'] as String?) ?? '';
    final ratingCount = (row['rating_count'] as num?)?.toInt() ?? 0;
    final ratingAvg = double.tryParse('${row['rating_avg'] ?? 0}') ?? 0;
    final picked = ref.watch(deliverySelectionProvider
        .select((s) => s.preferredQassobId == id));
    return InkWell(
      onTap: () => ref.read(deliverySelectionProvider.notifier).togglePreferredQassob(id),
      borderRadius: BorderRadius.circular(14),
      child: Container(width: 170,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: picked ? cs.primary.withValues(alpha: 0.10) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: picked ? cs.primary : cs.outlineVariant,
                width: picked ? 1.5 : 1)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Stack(clipBehavior: Clip.none, children: [
            CircleAvatar(radius: 22, backgroundColor: cs.primary.withValues(alpha: 0.10),
                foregroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                child: Icon(Icons.cut_rounded, color: cs.primary)),
            if (picked) Positioned(right: -2, bottom: -2,
              child: Container(width: 18, height: 18,
                decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5)),
                child: const Icon(Icons.check, color: Colors.white, size: 12))),
          ]),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Row(children: [
              const Icon(Icons.star_rounded, size: 13, color: Color(0xFFEF9A00)),
              const SizedBox(width: 2),
              Text(ratingCount > 0 ? ratingAvg.toStringAsFixed(1) : '—',
                  style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(width: 4),
              // Info button opens the full detail page — separate from the card tap.
              InkWell(onTap: () => context.push('/servislar/$id'),
                borderRadius: BorderRadius.circular(999),
                child: Padding(padding: const EdgeInsets.all(4),
                  child: Icon(Icons.info_outline_rounded, size: 14,
                      color: cs.onSurfaceVariant))),
            ]),
          ])),
        ])));
  }
}


// ---------- Section: Price breakdown ----------

class _BreakdownCard extends StatelessWidget {
  final int productsSoum, deliverySoum, butcherSoum;
  const _BreakdownCard({required this.productsSoum, required this.deliverySoum, required this.butcherSoum});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final total = productsSoum + deliverySoum + butcherSoum;
    return _SectionShell(
      title: t.deliveryBreakdownSection,
      child: Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(children: [
          _Row(label: t.deliveryBreakdownProducts, soum: productsSoum, bold: false),
          const SizedBox(height: 8),
          _Row(label: t.deliveryBreakdownDelivery, soum: deliverySoum, bold: false),
          if (butcherSoum > 0) ...[
            const SizedBox(height: 8),
            _Row(label: t.deliveryBreakdownButcher, soum: butcherSoum, bold: false),
          ],
          const SizedBox(height: 10),
          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(t.deliveryBreakdownTotal, style: tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w900, letterSpacing: 0.4)),
            Text('${formatSoum(total)} so\'m',
                style: tt.titleLarge?.copyWith(color: cs.primary, fontWeight: FontWeight.w900)),
          ]),
        ])),
    );
  }
}


class _Row extends StatelessWidget {
  final String label;
  final int soum;
  final bool bold;
  const _Row({required this.label, required this.soum, required this.bold});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
      Text('${formatSoum(soum)} so\'m', style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
    ]);
  }
}


// ---------- Section shell ----------

class _SectionShell extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _SectionShell({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35), width: 0.6)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
          child: Row(children: [
            Expanded(child: Text(title, style: tt.titleSmall?.copyWith(
                fontWeight: FontWeight.w800, letterSpacing: 0.2,
                color: cs.onSurface.withValues(alpha: 0.85)))),
            ?trailing,
          ])),
        child,
      ]),
    );
  }
}


// ---------- Sticky checkout bar ----------

class _CheckoutBar extends ConsumerStatefulWidget {
  final EffectiveDeliveryLocation eff;
  final bool canProceed;
  const _CheckoutBar({required this.eff, required this.canProceed});
  @override
  ConsumerState<_CheckoutBar> createState() => _CheckoutBarState();
}


class _CheckoutBarState extends ConsumerState<_CheckoutBar> {
  bool _submitting = false;

  Future<void> _onTap() async {
    final t = AppLocalizations.of(context);
    HapticFeedback.mediumImpact();
    // Capture context-dependent handles BEFORE any await so we don't read context after deactivation
    // (this is the same defensive pattern the cart's checkout button uses — see cart_screen.dart).
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // Auth gate — anonymous buyers can browse + see prices, but POST /orders/ requires login. Instead
    // of letting them tap the button and seeing a raw 401, route them to the phone-login flow with a
    // pending redirect back to /delivery. After a successful login the cart + selections are still in
    // memory (Riverpod providers persist across the auth screens), so they land right back where they
    // left off and can finish checkout in one more tap.
    final auth = ref.read(authNotifierProvider);
    if (auth is! AuthAuthenticated) {
      ref.read(pendingRedirectProvider.notifier).set('/delivery');
      router.push('/auth/phone');
      return;
    }

    final eff = widget.eff;
    if (eff.unresolved) {
      messenger.showSnackBar(SnackBar(content: Text(t.deliveryNeedAddress)));
      return;
    }
    final cart = ref.read(cartProvider);
    final selection = ref.read(deliverySelectionProvider);
    final vehicle = selection.selectedVehicle;
    if (vehicle == null || selection.timeSlotCode == null) return;

    setState(() => _submitting = true);
    final repo = ref.read(ordersRepositoryProvider);
    final List<int> createdIds = [];
    String? error;

    // We split the delivery fee across all cart lines so each order has a per-line share. For a single-
    // line cart this is identical to the quote. For multi-line, the buyer sees ONE delivery cost in the
    // breakdown but every order row carries its share so totals reconcile server-side.
    final lineCount = cart.items.length;
    final perLineDelivery = lineCount == 0 ? 0.0 : vehicle.totalPrice / lineCount;
    final perLineButcher = lineCount == 0 ? 0.0 : selection.butcherFee / lineCount;
    // Use the effective location's clamped coords (already snapped to Tashkent if needed) + the saved
    // address's text label when present. When no saved address, fall back to the resolved label as the
    // shipping address text (e.g. "Mening joylashuvim — Toshkent").
    final shippingText = eff.savedAddress?.address ?? (eff.addressLine.isNotEmpty
        ? '${eff.label.isNotEmpty && eff.label != kCurrentLocationFallbackLabel ? "${eff.label}, " : ""}${eff.addressLine}'
        : 'Toshkent');

    try {
      for (final item in cart.items.values) {
        final order = await repo.placeOrderWithDelivery(
          listingId: item.listing.id,
          quantityKg: item.qty.toDouble(),
          deliveryAddress: shippingText,
          deliveryVehicleType: vehicle.code,
          deliveryTimeSlot: selection.timeSlotCode!,
          deliveryDistanceKm: vehicle.distanceKm,
          deliveryLat: eff.lat,
          deliveryLng: eff.lng,
          deliveryPrice: perLineDelivery,
          butcherServiceRequested: selection.butcherRequested,
          butcherServiceFee: perLineButcher,
          // v3.9.15 — pass the buyer's picked qassob (null if they didn't pick one). Repository only
          // includes the field on the wire when butcher service is on, so this is safe to always pass.
          preferredQassobId: selection.preferredQassobId,
        );
        createdIds.add(order.id);
      }
    } on ApiException catch (e) { error = e.message; }
    catch (e) { error = e.toString(); }

    if (!mounted) return;
    setState(() => _submitting = false);

    if (error != null && createdIds.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    ref.read(cartProvider.notifier).clear();
    if (createdIds.length == 1) {
      router.push('/orders/${createdIds.first}/pay');
    } else {
      router.go('/orders');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(decoration: BoxDecoration(color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)))),
      child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: SizedBox(width: double.infinity, height: 54, child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: widget.canProceed ? cs.primary : cs.surfaceContainerHighest,
            foregroundColor: widget.canProceed ? cs.onPrimary : cs.onSurfaceVariant,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          onPressed: (!widget.canProceed || _submitting) ? null : _onTap,
          child: _submitting
              ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(
                  strokeWidth: 2.4, color: Colors.white))
              : Text(t.deliveryProceedCta, style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800))))),
    );
  }
}
