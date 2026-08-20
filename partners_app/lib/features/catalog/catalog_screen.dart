import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/providers.dart';
import '../../l10n/app_localizations.dart';

/// Internal platform catalog. Listings are the primary object: operators can search, filter,
/// inspect, change prices, archive/reactivate, delete, and add new entries from one place.
class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _status = 'ALL';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final async = ref.watch(myListingsProvider);

    return Stack(children: [
      RefreshIndicator(
        onRefresh: () async => ref.invalidate(myListingsProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 72, 24, 120),
            children: [
              Icon(Icons.cloud_off_rounded, size: 56, color: cs.error),
              const SizedBox(height: 12),
              Text(error.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.error)),
              const SizedBox(height: 16),
              Center(
                  child: OutlinedButton.icon(
                onPressed: () => ref.invalidate(myListingsProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(t.tryAgain),
              )),
            ],
          ),
          data: (rows) {
            final filtered = rows.where((row) {
              final matchesStatus =
                  _status == 'ALL' || row['status'] == _status;
              final needle = _query.trim().toLowerCase();
              if (!matchesStatus) return false;
              if (needle.isEmpty) return true;
              final haystack = [
                row['id'],
                row['name_uz'],
                row['name_ru'],
                _nestedName(row['category']),
              ].whereType<Object>().join(' ').toLowerCase();
              return haystack.contains(needle);
            }).toList();

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 108),
              children: [
                _CatalogSummary(total: rows.length),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: t.catalogSearchHint,
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: t.cancel,
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                    filled: true,
                    fillColor: cs.surfaceContainerLowest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: cs.outlineVariant),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _StatusFilter(
                      label: t.catalogFilterAll,
                      selected: _status == 'ALL',
                      onSelected: () => setState(() => _status = 'ALL'),
                    ),
                    _StatusFilter(
                      label: t.catalogFilterActive,
                      selected: _status == 'ACTIVE',
                      onSelected: () => setState(() => _status = 'ACTIVE'),
                    ),
                    _StatusFilter(
                      label: t.catalogFilterOutOfStock,
                      selected: _status == 'OUT_OF_STOCK',
                      onSelected: () =>
                          setState(() => _status = 'OUT_OF_STOCK'),
                    ),
                    _StatusFilter(
                      label: t.catalogFilterArchived,
                      selected: _status == 'ARCHIVED',
                      onSelected: () => setState(() => _status = 'ARCHIVED'),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 44, 28, 0),
                    child: Column(children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 58, color: cs.onSurfaceVariant),
                      const SizedBox(height: 12),
                      Text(rows.isEmpty ? t.catalogEmpty : t.catalogNoMatches,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(color: cs.onSurfaceVariant),
                          textAlign: TextAlign.center),
                    ]),
                  )
                else
                  ...filtered.indexed.expand((entry) sync* {
                    if (entry.$1 > 0) yield const SizedBox(height: 10);
                    yield _ListingCard(row: entry.$2);
                  }),
              ],
            );
          },
        ),
      ),
      Positioned(
        right: 16,
        bottom: 18,
        child: FloatingActionButton.extended(
          onPressed: () async {
            final id = await context.push<int>('/catalog/new');
            if (id != null) ref.invalidate(myListingsProvider);
          },
          icon: const Icon(Icons.add_rounded),
          label: Text(t.catalogAddNew),
        ),
      ),
    ]);
  }
}

String _nestedName(dynamic value) {
  if (value is Map) {
    return '${value['name_uz'] ?? ''} ${value['name_ru'] ?? ''}';
  }
  return value?.toString() ?? '';
}

/// Fetch every page from the owner-scoped endpoint. The old UI silently stopped after the first
/// page, which made older listings impossible to manage from the app.
final myListingsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(apiClientProvider).dio;
  final rows = <Map<String, dynamic>>[];
  final visited = <String>{};
  String? next = '/listings/my/';

  while (next != null && visited.add(next)) {
    final response = await dio.get(next);
    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      final data = response.data;
      final detail = data is Map ? data['detail']?.toString() : null;
      throw Exception(detail ?? 'HTTP $status');
    }
    final data = response.data;
    if (data is List) {
      rows.addAll(data.cast<Map<String, dynamic>>());
      next = null;
    } else if (data is Map) {
      final results = data['results'];
      if (results is List) rows.addAll(results.cast<Map<String, dynamic>>());
      final rawNext = data['next'];
      next = rawNext is String && rawNext.isNotEmpty ? rawNext : null;
    } else {
      next = null;
    }
  }
  return rows;
});

class _CatalogSummary extends StatelessWidget {
  final int total;

  const _CatalogSummary({required this.total});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Icon(Icons.inventory_2_rounded, color: cs.onPrimaryContainer),
        const SizedBox(width: 10),
        Expanded(
            child: Text(t.internalCatalogTitle,
                style: tt.titleMedium?.copyWith(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w800))),
        Text(t.catalogTotal(total),
            style: tt.labelLarge?.copyWith(
                color: cs.onPrimaryContainer, fontWeight: FontWeight.w900)),
      ]),
    );
  }
}

class _StatusFilter extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _StatusFilter({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onSelected(),
        ),
      );
}

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
        text: widget.row['price_per_kg']?.toString() ?? '');
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(t.catalogQuickPriceTitle,
                style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                  suffixText: widget.row['is_live_animal'] == true
                      ? "so'm/bosh"
                      : "so'm/kg"),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final value = double.tryParse(ctrl.text.trim());
                  if (value != null && value > 0) {
                    Navigator.pop(ctx, ctrl.text.trim());
                  }
                },
                child: Text(t.save),
              ),
            ),
          ]),
        ),
      ),
    );
    ctrl.dispose();
    if (result == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final response = await ref.read(apiClientProvider).dio.post(
        '/partner/listings/${widget.row['id']}/quick-price/',
        data: {'price_per_kg': result},
      );
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        final data = response.data;
        final detail = data is Map ? data['detail']?.toString() : null;
        throw Exception(detail ?? 'HTTP $status');
      }
      ref.invalidate(myListingsProvider);
      messenger.showSnackBar(SnackBar(content: Text(t.catalogPriceUpdated)));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _openDetail() async {
    final id = (widget.row['id'] as num?)?.toInt();
    if (id == null) return;
    final changed = await context.push<bool>('/catalog/$id');
    if (changed == true) ref.invalidate(myListingsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final row = widget.row;
    final isLive = row['is_live_animal'] == true;
    final quantity = isLive
        ? (row['head_count']?.toString() ??
            row['quantity_kg']?.toString() ??
            '0')
        : (row['quantity_kg']?.toString() ?? '0');
    final quantityLabel =
        isLive ? t.catalogHeadCount(quantity) : t.catalogStock(quantity);
    final status = row['status']?.toString() ?? '';
    final photoUrl = _firstPhoto(row);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: _openDetail,
        onLongPress: _quickPrice,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 64,
                height: 64,
                child: photoUrl.isEmpty
                    ? ColoredBox(
                        color: cs.surfaceContainerLowest,
                        child: Icon(Icons.image_outlined,
                            color: cs.onSurfaceVariant),
                      )
                    : Image.network(photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => ColoredBox(
                              color: cs.surfaceContainerLowest,
                              child: Icon(Icons.broken_image_outlined,
                                  color: cs.onSurfaceVariant),
                            )),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child: Text(
                    (row['name_uz'] ?? row['name_ru'] ?? '—').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  )),
                  if (status.isNotEmpty) _StatusPill(status: status),
                ]),
                const SizedBox(height: 5),
                Text(quantityLabel,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 3),
                Text(
                  "${row['price_per_kg'] ?? '0'} so'm/${isLive ? 'bosh' : 'kg'}",
                  style: tt.titleSmall?.copyWith(
                      color: cs.primary, fontWeight: FontWeight.w800),
                ),
              ],
            )),
            IconButton(
              tooltip: t.catalogQuickPriceTitle,
              onPressed: _quickPrice,
              icon: const Icon(Icons.price_change_outlined),
            ),
          ]),
        ),
      ),
    );
  }
}

String _firstPhoto(Map<String, dynamic> row) {
  final photos = row['photos'];
  if (photos is List && photos.isNotEmpty && photos.first is Map) {
    final first = photos.first as Map;
    return (first['url'] ?? first['image_url'] ?? '').toString();
  }
  return '';
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final (label, background, foreground) = switch (status) {
      'ACTIVE' => (
          t.catalogFilterActive,
          const Color(0xFFE8F5E9),
          const Color(0xFF1B5E20)
        ),
      'OUT_OF_STOCK' => (
          t.catalogFilterOutOfStock,
          const Color(0xFFFFF4E5),
          const Color(0xFF8A4F00)
        ),
      'ARCHIVED' => (
          t.catalogFilterArchived,
          const Color(0xFFEEEEEE),
          const Color(0xFF424242)
        ),
      _ => (status, const Color(0xFFEEEEEE), const Color(0xFF424242)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style: TextStyle(
              color: foreground, fontWeight: FontWeight.w800, fontSize: 10)),
    );
  }
}
