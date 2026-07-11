import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/models/listing.dart';
import '../../../shared/utils/format.dart';
import '../../auth/providers/auth_providers.dart' show apiClientProvider;
import '../../cart/presentation/cart_actions.dart';
import '../../listings/providers/listings_providers.dart';
import '../data/supplier_public.dart';


/// Bilingual (UZ + RU) inline text — English is deliberately not supported per the project's UZ+RU scope.
String _t(BuildContext c, String uz, String ru) =>
    Localizations.localeOf(c).languageCode == 'ru' ? ru : uz;


/// Full-page supplier profile for the buyer app. Reached from the listing detail's "Sotuvchi
/// haqida" row. Similar shape to qassob_detail_screen.dart but simpler — suppliers sell products,
/// not services, so there's no working-hours / price-list / gallery grid.
///
/// Layout:
///   • Hero: photo + name + business_name
///   • Info row: region, phone tap-to-call, listings count
///   • Address block
///
/// No chat CTA — v3.9.13 disabled chat for suppliers (they don't negotiate custom work).
class SupplierDetailScreen extends ConsumerWidget {
  final int userId;
  const SupplierDetailScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_supplierPublicProvider(userId));
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sotuvchi profili"),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => context.pop())),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString(), style: TextStyle(color: cs.error))),
        data: (s) => s == null ? _empty(context) : _body(context, s),
      ),
    );
  }

  Widget _empty(BuildContext ctx) => const Center(child: Padding(padding: EdgeInsets.all(24),
      child: Text("Sotuvchi profili topilmadi", textAlign: TextAlign.center)));

  Widget _body(BuildContext context, SupplierPublic s) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 32), children: [
      // ---- Hero photo (circular) + names
      Center(child: Column(children: [
        Container(width: 120, height: 120,
          decoration: BoxDecoration(shape: BoxShape.circle,
              color: cs.primary.withValues(alpha: 0.10),
              border: Border.all(color: cs.outlineVariant)),
          child: s.photoUrl.isEmpty
              ? Icon(Icons.storefront_rounded, size: 60, color: cs.primary)
              : ClipOval(child: Image.network(s.photoUrl, fit: BoxFit.cover,
                  width: 120, height: 120,
                  errorBuilder: (_, err, stack) =>
                      Icon(Icons.storefront_rounded, size: 60, color: cs.primary)))),
        const SizedBox(height: 14),
        Text(s.businessName.isNotEmpty ? s.businessName : s.fullName,
            textAlign: TextAlign.center,
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w900,
                letterSpacing: -0.4)),
        if (s.businessName.isNotEmpty && s.fullName.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(s.fullName,
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ])),
      const SizedBox(height: 24),
      // ---- Info rows
      _InfoRow(icon: Icons.location_on_rounded, label: 'Hudud',
          value: s.region.isNotEmpty ? s.region : "Ma'lumot yo'q"),
      if (s.address.isNotEmpty)
        _InfoRow(icon: Icons.map_rounded, label: 'Manzil', value: s.address),
      // Tappable — opens a popup of this supplier's active listings with add-to-cart, instead of only
      // showing the count. Chevron + primary color signal it's interactive.
      _InfoRow(icon: Icons.inventory_2_rounded,
          label: _t(context, 'Faol tovarlar', 'Активные товары'),
          value: _t(context, "${s.listingsCount} ta · ko'rish", '${s.listingsCount} · смотреть'),
          valueColor: cs.primary,
          onTap: s.listingsCount == 0
              ? null
              : () => _showSupplierListings(context, s.userId)),
      if (s.phone.isNotEmpty)
        _InfoRow(icon: Icons.phone_rounded, label: 'Telefon',
            value: s.phone,
            onTap: () => launchUrl(Uri.parse('tel:${s.phone}'),
                mode: LaunchMode.externalApplication),
            valueColor: cs.primary),
    ]);
  }
}


final _supplierPublicProvider = FutureProvider.autoDispose.family<SupplierPublic?, int>(
    (ref, id) async {
  try {
    final r = await ref.read(apiClientProvider).dio.get('/suppliers/public/$id/');
    if (r.statusCode == 200 && r.data is Map) {
      return SupplierPublic.fromJson(Map<String, dynamic>.from(r.data as Map));
    }
  } catch (_) {}
  return null;
});


class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback? onTap;
  const _InfoRow({required this.icon, required this.label, required this.value,
                   this.valueColor, this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14),
      child: Container(margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant)),
        child: Row(children: [
          Icon(icon, color: cs.onSurfaceVariant, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(label,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant))),
          Text(value,
              style: tt.titleSmall?.copyWith(color: valueColor ?? cs.onSurface,
                  fontWeight: FontWeight.w800)),
          if (onTap != null) Padding(padding: const EdgeInsets.only(left: 6),
              child: Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant)),
        ])));
  }
}


// ---------- Supplier active-listings popup ----------

/// One supplier's ACTIVE listings (public browse is ACTIVE-only). autoDispose so it frees when the sheet closes.
final _supplierListingsProvider = FutureProvider.autoDispose.family<List<Listing>, int>((ref, supplierId) async {
  final page = await ref.read(listingsRepositoryProvider).browse(supplierId: supplierId);
  return page.results;
});


void _showSupplierListings(BuildContext context, int supplierId) {
  showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => _SupplierListingsSheet(supplierId: supplierId));
}


class _SupplierListingsSheet extends ConsumerWidget {
  final int supplierId;
  const _SupplierListingsSheet({required this.supplierId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final async = ref.watch(_supplierListingsProvider(supplierId));
    return DraggableScrollableSheet(
      initialChildSize: 0.7, minChildSize: 0.4, maxChildSize: 0.92, expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(color: Color(0xFFFFFBF7),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2))),
          Padding(padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
            child: Row(children: [
              Expanded(child: Text(_t(context, 'Faol tovarlar', 'Активные товары'),
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w900,
                      color: const Color(0xFF1A1A1A)))),
              IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
            ])),
          Expanded(child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24),
                child: Text(_t(context, "Yuklab bo'lmadi", 'Не удалось загрузить'),
                    style: TextStyle(color: cs.error)))),
            data: (items) {
              if (items.isEmpty) {
                return Center(child: Text(_t(context, "Faol tovarlar yo'q", 'Нет активных товаров'),
                    style: TextStyle(color: cs.onSurfaceVariant)));
              }
              return ListView.separated(controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _SupplierListingCard(listing: items[i]));
            },
          )),
        ])));
  }
}


/// Compact product card in the supplier-listings popup: photo, name, price/kg, and a "+" that adds to the
/// cart through the single-product guard. Tapping the card opens the full product detail.
class _SupplierListingCard extends ConsumerWidget {
  final Listing listing;
  const _SupplierListingCard({required this.listing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;
    final name = lang == 'ru' && listing.nameRu.isNotEmpty ? listing.nameRu : listing.nameUz;
    final photo = listing.primaryPhotoUrl;
    final unit = listing.isByHead ? _t(context, "so'm/bosh", 'сум/голова') : _t(context, "so'm/kg", 'сум/кг');
    return InkWell(onTap: () => context.push('/listings/${listing.id}'),
      borderRadius: BorderRadius.circular(16),
      child: Container(padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(16), border: Border.all(color: cs.outlineVariant)),
        child: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(12),
            child: SizedBox(width: 64, height: 64,
              child: (photo == null || photo.isEmpty)
                  ? Container(color: cs.surfaceContainerHighest,
                      child: Icon(Icons.image_outlined, color: cs.onSurfaceVariant))
                  : Image.network(photo, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: cs.surfaceContainerHighest,
                          child: Icon(Icons.broken_image_outlined, color: cs.onSurfaceVariant))))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A1A1A))),
            const SizedBox(height: 4),
            Text('${formatSoum(listing.pricePerKg.round())} $unit',
                style: tt.bodyMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w800)),
          ])),
          const SizedBox(width: 8),
          Material(color: cs.primary, shape: const CircleBorder(),
            child: InkWell(customBorder: const CircleBorder(),
              onTap: () => addToCartOrPrompt(context, ref, listing),
              child: const Padding(padding: EdgeInsets.all(8),
                  child: Icon(Icons.add_rounded, color: Colors.white)))),
        ])));
  }
}
