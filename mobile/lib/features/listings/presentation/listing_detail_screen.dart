// Listing detail — Apple-style hero (oversized title + supplier subtitle), grouped key facts, sticky-feeling CTAs at bottom.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/l10n/enum_labels.dart';
import '../../../shared/models/listing.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/providers/auth_state.dart';
import '../../chats/providers/chats_providers.dart';
import '../../favorites/presentation/heart_button.dart';
import '../../orders/providers/orders_providers.dart';
import '../data/listings_repository.dart' show ApiException;
import '../providers/listings_providers.dart';
import 'package:go_router/go_router.dart';


class ListingDetailScreen extends ConsumerWidget {
  final int listingId;
  const ListingDetailScreen({super.key, required this.listingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final async = ref.watch(listingByIdProvider(listingId));
    return Scaffold(
      appBar: AppBar(
        title: Text(t.listingDetailTitle),
        // Heart toggle in the AppBar — same gesture surface across all screens that show a listing's detail
        actions: [HeartButton(listingId: listingId)],
      ),
      body: async.when(
        data: (listing) => _ListingDetailBody(listing: listing),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(t.failedPrefix(e.toString()))),
      ),
    );
  }
}


class _ListingDetailBody extends ConsumerWidget {
  final Listing listing;
  const _ListingDetailBody({required this.listing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final auth = ref.watch(authNotifierProvider);
    final isOwner = auth is AuthAuthenticated && auth.user.email == listing.supplierEmail;
    final isBuyer = auth is AuthAuthenticated && auth.user.isBuyer;
    final canOrder = isBuyer && listing.status == ListingStatus.active;

    return SingleChildScrollView(padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Photo gallery — full-bleed PageView at the top. Falls back to a soft placeholder when no photos exist.
        _PhotoGallery(photos: listing.photos),
        Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Hero section — large title, business name, type/status + halal pills
            Text(listing.title, style: tt.displaySmall),
            const SizedBox(height: 6),
            Text(listing.supplierBusinessName.isEmpty ? listing.supplierEmail : listing.supplierBusinessName,
                 style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 14),
            Wrap(spacing: 8, children: [
              _Pill(text: listing.meatType.label(context), tone: _PillTone.neutral),
              _Pill(text: listing.status.label(context),
                    tone: listing.status == ListingStatus.active ? _PillTone.success : _PillTone.warn),
              if (listing.halalCertified) _Pill(text: t.halal, tone: _PillTone.success),
              _Pill(text: _coldChainLabel(t, listing.coldChain), tone: _PillTone.neutral),
            ]),
            const SizedBox(height: 28),

        // Pricing block — visually anchors the page; uses the same tone language as the home stat tiles
        Container(padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.listingFieldPricePerKg.toUpperCase(),
                style: tt.labelSmall?.copyWith(color: cs.onPrimaryContainer.withValues(alpha: 0.7))),
              const SizedBox(height: 4),
              Text(listing.pricePerKg.toStringAsFixed(2), style: tt.headlineLarge?.copyWith(color: cs.onPrimaryContainer)),
            ])),
            Container(width: 1, height: 40, color: cs.onPrimaryContainer.withValues(alpha: 0.15)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.listingFieldAvailable.toUpperCase(),
                style: tt.labelSmall?.copyWith(color: cs.onPrimaryContainer.withValues(alpha: 0.7))),
              const SizedBox(height: 4),
              Text('${listing.quantityKg.toStringAsFixed(2)} kg', style: tt.headlineSmall?.copyWith(color: cs.onPrimaryContainer)),
            ])),
          ])),
        const SizedBox(height: 24),

            // Grouped fact list — iOS Settings-style rows. Conditional rows for freshness / service area only when set.
            _GroupedList(items: [
              (t.listingFieldLocation, listing.location),
              (t.listingFieldAvailableFrom, listing.availableFrom),
              (t.listingFieldMeatType, listing.meatType.label(context)),
              if (listing.freshnessDate != null) (t.freshnessDate, listing.freshnessDate!),
              if (listing.serviceAreaCsv.isNotEmpty) (t.serviceArea, listing.serviceAreaCsv),
            ]),

            if (listing.description.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(t.listingFieldDescription.toUpperCase(),
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant, letterSpacing: 0.6)),
              const SizedBox(height: 8),
              Text(listing.description, style: tt.bodyLarge),
            ],
            const SizedBox(height: 32),

            // CTAs
            if (canOrder) FilledButton.icon(icon: const Icon(Icons.shopping_cart_outlined),
                label: Text(t.listingActionPlaceOrder),
                onPressed: () => _showOrderSheet(context, ref, listing)),
            // Chat with seller — only visible to non-owners; opens (or reuses) the 1:1 conversation and routes to it
            if (!isOwner && auth is AuthAuthenticated) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(icon: const Icon(Icons.forum_outlined),
                label: Text(t.tabChats),
                onPressed: () => _openChatWithSeller(context, ref, listing)),
            ],
            if (isOwner) ...[
              OutlinedButton.icon(icon: const Icon(Icons.edit_outlined), label: Text(t.listingActionEdit),
                  onPressed: () => _showEditSheet(context, ref, listing)),
              const SizedBox(height: 8),
              OutlinedButton.icon(icon: const Icon(Icons.visibility_off_outlined), label: Text(t.listingActionDeactivate),
                  onPressed: listing.status == ListingStatus.inactive ? null
                           : () => _toggleStatus(context, ref, listing, ListingStatus.inactive)),
            ],
          ]))]));
  }

  /// Cold chain enum → translated label using the existing ARB keys.
  static String _coldChainLabel(AppLocalizations t, ColdChain c) => switch (c) {
    ColdChain.fresh => t.coldChainFresh,
    ColdChain.chilled => t.coldChainChilled,
    ColdChain.frozen => t.coldChainFrozen,
  };

  /// Open (or create) a 1:1 chat with this listing's supplier, then route to the chat detail screen.
  /// We resolve supplier_user_id via the supplier_email on the listing — backend's start endpoint takes user id.
  Future<void> _openChatWithSeller(BuildContext context, WidgetRef ref, Listing l) async {
    // Backend's start endpoint needs the other user's id. Our listing only carries supplier_email — for now we look up
    // the user via /api/v1/auth/me/-like lookup. Quick path: assume backend exposes supplier id via list endpoint;
    // simplest robust path: bail with a TODO message until /listings serializer includes supplier_user_id.
    try {
      final conv = await ref.read(chatsRepositoryProvider).startWith(_extractSupplierId(l));
      if (context.mounted) context.push('/chats/${conv.id}');
    } on ApiException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  /// Backend's ListingSerializer now exposes supplier_id (v2 Milestone C); we just hand it to /chats/start/.
  int _extractSupplierId(Listing l) => l.supplierId;

  /// Order placement bottom-sheet — clean form with live oversell guard and confirm CTA.
  void _showOrderSheet(BuildContext context, WidgetRef ref, Listing l) {
    final t = AppLocalizations.of(context);
    final qty = TextEditingController();
    final addr = TextEditingController();
    final notes = TextEditingController();
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (sheetCtx) {
      String? error; bool submitting = false;
      return StatefulBuilder(builder: (sheetCtx, setSheet) =>
        Padding(padding: EdgeInsets.only(left: 20, right: 20, top: 4,
                                         bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(t.orderPlaceTitle(l.title), style: Theme.of(sheetCtx).textTheme.titleLarge,
                 maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(t.orderAvailabilityHint(l.quantityKg.toStringAsFixed(2), l.pricePerKg.toStringAsFixed(2)),
                 style: Theme.of(sheetCtx).textTheme.bodySmall),
            const SizedBox(height: 20),
            TextField(controller: qty, keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: t.listingFieldQuantity)),
            const SizedBox(height: 12),
            TextField(controller: addr, maxLines: 2,
              decoration: InputDecoration(labelText: t.orderFieldDeliveryAddress)),
            const SizedBox(height: 12),
            TextField(controller: notes, maxLines: 2,
              decoration: InputDecoration(labelText: t.orderFieldNotesOptional)),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 12),
                child: Text(error!, style: TextStyle(color: Theme.of(sheetCtx).colorScheme.error))),
            const SizedBox(height: 20),
            FilledButton(onPressed: submitting ? null : () async {
              final q = double.tryParse(qty.text) ?? 0;
              if (q <= 0 || addr.text.trim().isEmpty) { setSheet(() => error = t.orderQtyAddrRequired); return; }
              if (q > l.quantityKg) { setSheet(() => error = t.orderOnlyKgAvailable(l.quantityKg.toStringAsFixed(2))); return; }
              setSheet(() { submitting = true; error = null; });
              try {
                await ref.read(ordersRepositoryProvider).placeOrder(
                    listingId: l.id, quantityKg: q, deliveryAddress: addr.text.trim(), notes: notes.text.trim());
                ref..invalidate(listingByIdProvider(l.id))..invalidate(listingsBrowseProvider)
                   ..invalidate(myOrdersProvider);
                if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.orderPlacedSnack)));
                }
              } catch (e) { setSheet(() { error = e.toString(); submitting = false; }); }
            }, child: submitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(t.orderConfirmButton)),
          ])));
    });
  }

  /// Quick edit — clean sheet for price + description.
  void _showEditSheet(BuildContext context, WidgetRef ref, Listing l) {
    final t = AppLocalizations.of(context);
    final price = TextEditingController(text: l.pricePerKg.toStringAsFixed(2));
    final desc = TextEditingController(text: l.description);
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) =>
      Padding(padding: EdgeInsets.only(left: 20, right: 20, top: 4,
                                       bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(t.listingActionEdit, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(controller: price, keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: t.listingFieldPricePerKg)),
          const SizedBox(height: 12),
          TextField(controller: desc, maxLines: 3, decoration: InputDecoration(labelText: t.listingFieldDescription)),
          const SizedBox(height: 20),
          FilledButton(onPressed: () async {
            try {
              await ref.read(listingsRepositoryProvider).update(l.id,
                  {'price_per_kg': price.text, 'description': desc.text});
              ref..invalidate(listingByIdProvider(l.id))..invalidate(listingsBrowseProvider)..invalidate(myListingsProvider);
              if (context.mounted) Navigator.pop(context);
            } catch (e) {
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
            }
          }, child: Text(t.listingActionSave)),
        ])));
  }

  Future<void> _toggleStatus(BuildContext context, WidgetRef ref, Listing l, ListingStatus newStatus) async {
    final wire = switch (newStatus) {
      ListingStatus.active => 'ACTIVE', ListingStatus.soldOut => 'SOLD_OUT', ListingStatus.inactive => 'INACTIVE',
    };
    try {
      await ref.read(listingsRepositoryProvider).update(l.id, {'status': wire});
      ref..invalidate(listingByIdProvider(l.id))..invalidate(listingsBrowseProvider)..invalidate(myListingsProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}


/// Photo gallery — swipeable PageView at the top of the detail screen. Indicator dots overlay when multiple photos.
class _PhotoGallery extends StatefulWidget {
  final List<ListingPhoto> photos;
  const _PhotoGallery({required this.photos});
  @override
  State<_PhotoGallery> createState() => _PhotoGalleryState();
}


class _PhotoGalleryState extends State<_PhotoGallery> {
  final _controller = PageController();
  int _current = 0;

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Empty state — fixed-height placeholder so the layout stays stable when a listing has no photos yet
    if (widget.photos.isEmpty) {
      return Container(height: 240, color: cs.surfaceContainerHighest,
        child: Center(child: Icon(Icons.image_outlined, size: 56, color: cs.onSurfaceVariant)));
    }
    return SizedBox(height: 280, child: Stack(children: [
      PageView.builder(controller: _controller, itemCount: widget.photos.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (_, i) => Image.network(widget.photos[i].url, fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(color: cs.surfaceContainerHighest,
              child: Icon(Icons.broken_image_outlined, size: 56, color: cs.onSurfaceVariant)))),
      // Indicator dots — only when there's >1 photo to swipe between
      if (widget.photos.length > 1) Positioned(bottom: 12, left: 0, right: 0,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (int i = 0; i < widget.photos.length; i++) Container(
            width: 6, height: 6, margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: i == _current ? cs.onSurface : cs.onSurface.withValues(alpha: 0.4))),
        ])),
    ]));
  }
}


enum _PillTone { neutral, success, warn }


/// Same Pill widget used in the listings list — kept private here to avoid premature shared-widget extraction.
class _Pill extends StatelessWidget {
  final String text;
  final _PillTone tone;
  const _Pill({required this.text, this.tone = _PillTone.neutral});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (bg, fg) = switch (tone) {
      _PillTone.warn => (cs.errorContainer.withValues(alpha: 0.7), cs.onErrorContainer),
      _PillTone.success => (cs.tertiaryContainer.withValues(alpha: 0.7), cs.onTertiaryContainer),
      _PillTone.neutral => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
    };
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w500)));
  }
}


/// iOS Settings-style grouped list — label/value rows inside one rounded surface with hairline dividers.
class _GroupedList extends StatelessWidget {
  final List<(String, String)> items;
  const _GroupedList({required this.items});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(decoration: BoxDecoration(color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5), width: 0.5)),
      child: Column(children: [
        for (int i = 0; i < items.length; i++) ...[
          Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Expanded(child: Text(items[i].$1, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant))),
              Text(items[i].$2, style: tt.bodyMedium),
            ])),
          if (i < items.length - 1) Divider(height: 0.5, indent: 14, endIndent: 14,
              color: cs.outlineVariant.withValues(alpha: 0.5)),
        ],
      ]));
  }
}
