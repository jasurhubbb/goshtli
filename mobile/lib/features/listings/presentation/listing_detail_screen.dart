// ListingDetailScreen — Apple-style product detail. v3.1 catalog schema: bilingual name + description, nested
// market + category embeds, price in brand colour. Tap "Savatga qo'shish" adds the listing to the cart and
// returns to the previous screen.
//
// This screen is intentionally simple in v3.1 — full reviews / supplier-bio / photo carousel come later.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/listing.dart';
import '../../../shared/utils/format.dart';
import '../../cart/providers/cart_providers.dart';
import '../providers/listings_providers.dart';


class ListingDetailScreen extends ConsumerWidget {
  final int listingId;
  const ListingDetailScreen({super.key, required this.listingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(listingByIdProvider(listingId));
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => context.canPop() ? context.pop() : context.go('/'))),
      body: async.when(
        data: (l) => _body(context, ref, l),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24),
            child: Text(e.toString(), textAlign: TextAlign.center))),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, Listing l) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;

    return Column(children: [
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Photo (or category icon if none) — coloured surface, rounded corners
          AspectRatio(aspectRatio: 1.2,
            child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
                color: cs.surfaceContainerHighest),
              clipBehavior: Clip.antiAlias,
              child: l.primaryPhotoUrl != null
                  ? Image.network(l.primaryPhotoUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(Icons.image_outlined, size: 80, color: cs.onSurfaceVariant))
                  : Icon(Icons.restaurant_outlined, size: 80, color: cs.onSurfaceVariant))),
          const SizedBox(height: 18),
          Text(l.displayName(lang), style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('${l.market.displayName(lang)} · ${l.market.region}',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 14),
          Text('${formatSoum(l.pricePerKg.toInt())} so\'m/kg',
            style: tt.titleLarge?.copyWith(color: cs.primary, fontWeight: FontWeight.w800)),
          const SizedBox(height: 18),
          if ((lang == 'ru' ? l.descriptionRu : l.descriptionUz).isNotEmpty)
            Text(lang == 'ru' ? l.descriptionRu : l.descriptionUz,
                style: tt.bodyLarge?.copyWith(color: cs.onSurface.withValues(alpha: 0.85), height: 1.4)),
        ]))),

      // Sticky bottom CTA — full-width add-to-cart
      SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: SizedBox(width: double.infinity, height: 52, child: FilledButton(
          style: FilledButton.styleFrom(backgroundColor: cs.primary, foregroundColor: cs.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          onPressed: () {
            HapticFeedback.lightImpact();
            ref.read(cartProvider.notifier).add(l);
            if (context.canPop()) context.pop();
          },
          child: Text("Savatga qo'shish",
            style: tt.titleMedium?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w700))))))
    ]);
  }
}
