import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/providers/auth_providers.dart' show apiClientProvider;
import '../data/supplier_public.dart';


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
      _InfoRow(icon: Icons.inventory_2_rounded, label: 'Faol tovarlar',
          value: '${s.listingsCount} ta'),
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
