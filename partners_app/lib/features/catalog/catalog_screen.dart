import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/providers.dart';
import '../../l10n/app_localizations.dart';
import 'new_listing_sheet.dart';


/// Supplier catalog tab. Lists the supplier's own listings + a "+ new" FAB + long-press quick-price (F5).
class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final async = ref.watch(_myListingsProvider);
    return Stack(children: [
      RefreshIndicator(onRefresh: () async => ref.invalidate(_myListingsProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(e.toString(), style: TextStyle(color: cs.error))),
          data: (rows) {
            if (rows.isEmpty) {
              return ListView(children: [Padding(padding: const EdgeInsets.fromLTRB(32, 60, 32, 0),
                child: Center(child: Text(t.catalogEmpty,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center)))]);
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: rows.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _ListingCard(row: rows[i]),
            );
          })),
      Positioned(right: 16, bottom: 20,
        child: FloatingActionButton.extended(
            onPressed: () async {
              final id = await showNewListingSheet(context);
              if (id != null) ref.invalidate(_myListingsProvider);
            },
            icon: const Icon(Icons.add_rounded),
            label: Text(t.catalogAddNew))),
    ]);
  }
}


/// Defensive parser — `/listings/my/` returns a paginated `{count, next, previous, results: [...]}`
/// envelope on success, a `{detail: "..."}` map on 403/404, or a bare list in some old code paths.
/// We collapse all of these to a List so the UI never crashes on shape drift.
final _myListingsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final r = await ref.read(apiClientProvider).dio.get('/listings/my/');
  final data = r.data;
  if (data is List) return data.cast<Map<String, dynamic>>();
  if (data is Map) {
    final results = data['results'];
    if (results is List) return results.cast<Map<String, dynamic>>();
  }
  return const [];
});


class _ListingCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> row;
  const _ListingCard({required this.row});
  @override
  ConsumerState<_ListingCard> createState() => _ListingCardState();
}


class _ListingCardState extends ConsumerState<_ListingCard> {
  Future<void> _quickPrice() async {
    final t = AppLocalizations.of(context);
    final ctrl = TextEditingController(
        text: (widget.row['price_per_kg'] as String?) ?? '');
    final result = await showModalBottomSheet<String>(context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(t.catalogQuickPriceTitle,
                style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 14),
            TextField(controller: ctrl, autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(suffixText: "so'm/kg")),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: Text(t.save))),
          ]))));
    if (result == null) return;
    try {
      await ref.read(apiClientProvider).dio.post(
          '/partner/listings/${widget.row['id']}/quick-price/',
          data: {'price_per_kg': result});
      ref.invalidate(_myListingsProvider);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final r = widget.row;
    final qty = r['quantity_kg']?.toString() ?? '0';
    return GestureDetector(onLongPress: _quickPrice,
      child: Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((r['name_uz'] ?? r['name_ru'] ?? '—') as String,
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(t.catalogStock(qty),
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ])),
          Text('${r['price_per_kg']} so\'m',
              style: tt.titleSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w800)),
        ])));
  }
}
