import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/providers.dart';


/// Full-page listing detail for suppliers, reached from the Katalog row tap.
///
/// Layout (top → bottom):
///   • Photo hero (first photo from listing.photos, or placeholder)
///   • Name + status pill
///   • Quantity + price rows
///   • Category / market meta (compact)
///   • Delete button at the bottom (destructive)
///
/// Delete flow: confirm dialog → DELETE /listings/<id>/. Backend returns 400/403 with an Uzbek
/// message if any orders are still active — we surface that inline so the supplier knows exactly
/// what to do.
class ListingDetailScreen extends ConsumerStatefulWidget {
  final int listingId;
  const ListingDetailScreen({super.key, required this.listingId});
  @override
  ConsumerState<ListingDetailScreen> createState() => _ListingDetailScreenState();
}


/// Fetches a single listing by id via the public GET /listings/<id>/ endpoint. autoDispose so
/// leaving the page frees the cached JSON.
final _listingByIdProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, int>(
    (ref, id) async {
  try {
    final r = await ref.read(apiClientProvider).dio.get('/listings/$id/');
    if (r.statusCode == 200 && r.data is Map) {
      return Map<String, dynamic>.from(r.data as Map);
    }
  } catch (_) {}
  return null;
});


class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> {
  bool _deleting = false;
  String? _deleteError;

  Future<void> _confirmAndDelete(Map<String, dynamic> row) async {
    final name = (row['name_uz'] as String?) ?? (row['name_ru'] as String?) ?? '—';
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Tovarni o'chirishni tasdiqlaysizmi?"),
      content: Text("«$name» tovari o'chirilsinmi? "
                   "Bu amalni bekor qilib bo'lmaydi."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Bekor')),
        FilledButton.tonal(
          style: FilledButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text("O'chirish")),
      ]));
    if (ok != true || !mounted) return;
    await _delete();
  }

  Future<void> _delete() async {
    setState(() { _deleting = true; _deleteError = null; });
    HapticFeedback.selectionClick();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final r = await ref.read(apiClientProvider).dio.delete('/listings/${widget.listingId}/');
      final ok = (r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300);
      if (!ok) {
        final detail = (r.data is Map && r.data['detail'] is String)
            ? r.data['detail'] as String : 'HTTP ${r.statusCode}';
        setState(() { _deleteError = detail; _deleting = false; });
        return;
      }
      messenger.showSnackBar(const SnackBar(content: Text("Tovar o'chirildi")));
      if (mounted) context.pop(true);                                  // signals the parent list to refresh
    } on DioException catch (e) {
      final data = e.response?.data;
      final detail = (data is Map && data['detail'] is String)
          ? data['detail'] as String
          : (e.message ?? 'Tarmoq xatosi');
      setState(() { _deleteError = detail; _deleting = false; });
    } catch (e) {
      setState(() { _deleteError = e.toString(); _deleting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_listingByIdProvider(widget.listingId));
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text("Tovar tafsiloti"),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => context.pop())),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString(), style: TextStyle(color: cs.error))),
        data: (row) {
          if (row == null) {
            return const Center(child: Padding(padding: EdgeInsets.all(24),
                child: Text("Tovar topilmadi", textAlign: TextAlign.center)));
          }
          final name = (row['name_uz'] as String?) ?? (row['name_ru'] as String?) ?? '—';
          final qty = row['quantity_kg']?.toString() ?? '0';
          final price = row['price_per_kg']?.toString() ?? '0';
          final status = (row['status'] as String?) ?? '';
          final categoryName = _extractName(row['category']);
          final marketName = _extractName(row['market']);
          final photoUrl = _firstPhoto(row);

          return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
            // ---- Hero photo
            ClipRRect(borderRadius: BorderRadius.circular(18),
              child: SizedBox(width: double.infinity, height: 220,
                child: photoUrl.isNotEmpty
                    ? Image.network(photoUrl, fit: BoxFit.cover,
                        errorBuilder: (_, err, stack) => _photoPlaceholder(cs))
                    : _photoPlaceholder(cs))),
            const SizedBox(height: 20),
            // ---- Name + status pill
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Text(name,
                  style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w900,
                      letterSpacing: -0.4))),
              if (status.isNotEmpty) _StatusPill(status: status),
            ]),
            const SizedBox(height: 16),
            // ---- Info rows
            _InfoRow(label: 'Miqdor', value: '$qty kg', icon: Icons.scale_rounded),
            _InfoRow(label: 'Narx', value: "$price so'm / kg",
                icon: Icons.payments_rounded, valueColor: cs.primary),
            if (categoryName.isNotEmpty)
              _InfoRow(label: "Go'sht turi", value: categoryName,
                  icon: Icons.category_rounded),
            if (marketName.isNotEmpty)
              _InfoRow(label: 'Bozor', value: marketName,
                  icon: Icons.storefront_rounded),
            if (_deleteError != null) Padding(padding: const EdgeInsets.only(top: 16),
                child: Container(padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Icon(Icons.warning_amber_rounded, color: cs.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_deleteError!,
                        style: TextStyle(color: cs.onErrorContainer,
                            fontWeight: FontWeight.w700))),
                  ]))),
            const SizedBox(height: 30),
            // ---- Delete button (destructive)
            OutlinedButton.icon(onPressed: _deleting ? null : () => _confirmAndDelete(row),
              icon: _deleting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.red))
                  : const Icon(Icons.delete_outline_rounded, color: Colors.red),
              label: const Text("Tovarni o'chirish",
                  style: TextStyle(color: Colors.red,
                      fontSize: 15, fontWeight: FontWeight.w800)),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: Colors.red.withValues(alpha: 0.35)))),
          ]);
        },
      ),
    );
  }

  /// The `category` / `market` fields come back as either a bare id, a full nested object, or a
  /// name string depending on which serializer variant fired. Handle all three defensively.
  String _extractName(dynamic raw) {
    if (raw is Map) return (raw['name_uz'] ?? raw['name_ru'] ?? '').toString();
    if (raw is String) return raw;
    return '';
  }

  /// Photos are exposed as a list of `{id, image_url, position}` dicts. First (position=0) becomes
  /// the primary card image.
  String _firstPhoto(Map<String, dynamic> row) {
    final photos = row['photos'];
    if (photos is List && photos.isNotEmpty) {
      final first = photos.first;
      if (first is Map && first['image_url'] is String) {
        return first['image_url'] as String;
      }
    }
    return '';
  }

  Widget _photoPlaceholder(ColorScheme cs) =>
      Container(color: cs.surfaceContainerLowest,
        alignment: Alignment.center,
        child: Icon(Icons.image_outlined, size: 64, color: cs.onSurfaceVariant));
}


class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;
  const _InfoRow({required this.label, required this.value, required this.icon,
                   this.valueColor});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant)),
      child: Row(children: [
        Icon(icon, color: cs.onSurfaceVariant, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(label,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant))),
        Text(value, style: tt.titleSmall?.copyWith(
            color: valueColor ?? cs.onSurface, fontWeight: FontWeight.w800)),
      ]));
  }
}


class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});
  @override
  Widget build(BuildContext context) {
    // Status → Uzbek label + color pair. Kept in sync with backend Listing.Status enum.
    final (label, bg, fg) = switch (status) {
      'ACTIVE' => ('Faol', const Color(0xFFE3F2FD), const Color(0xFF0D47A1)),
      'OUT_OF_STOCK' => ('Zaxira tugagan', const Color(0xFFFFF4E5), const Color(0xFF8A4F00)),
      'ARCHIVED' => ('Arxivlangan', const Color(0xFFEEEEEE), const Color(0xFF424242)),
      _ => (status, const Color(0xFFEEEEEE), const Color(0xFF424242)),
    };
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: fg,
          fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.3)));
  }
}
