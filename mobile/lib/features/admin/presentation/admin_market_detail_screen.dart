// AdminMarketDetailScreen — opened when admin taps a Bozor in the Boshqarish > Bozorlar list.
//
// Shows:
//   • Header: name, region, address, phone (the editable identity of this Bozor)
//   • "Tahrirlash" button → reuses the editMarketDialog from admin_manage_section_screen.dart
//   • "Bozorni o'chirish" destructive button → soft-delete via deleteMarketConfirm + pops back to the list
//   • Listings list: filtered to this market via the buyer-side /listings/?market=<slug> query
//
// Why a dedicated screen instead of an expanded row: admin's actions on a Bozor are stateful (edit, delete,
// inspect listings) and don't all fit in a tile. The detail screen also gives a natural place to drill into
// a specific listing for edit.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/models/listing.dart';
import '../../listings/providers/listings_providers.dart';
import '../data/admin_models.dart';
import '../providers/admin_providers.dart';
import 'admin_manage_section_screen.dart' show editMarketDialog, deleteMarketConfirm;


/// Listings-for-this-market provider — keyed by market slug so multiple detail screens cache independently.
/// Uses the buyer-side ListingsRepository.browse with status omitted; backend admin-aware get_queryset returns
/// every status to ADMIN-role callers so admins see archived + out-of-stock listings here too.
final adminMarketListingsProvider =
    FutureProvider.autoDispose.family<List<Listing>, String>((ref, marketSlug) async {
  final repo = ref.watch(listingsRepositoryProvider);
  final page = await repo.browse(market: marketSlug, ordering: '-created_at');
  return page.results;
});


/// Single-market read so the detail screen always shows the latest values (in case admin came in from a
/// stale list cache). Keyed by id.
final adminMarketByIdProvider =
    FutureProvider.autoDispose.family<AdminMarket, int>((ref, id) =>
        ref.watch(adminRepositoryProvider).getMarket(id));


class AdminMarketDetailScreen extends ConsumerWidget {
  final int marketId;
  const AdminMarketDetailScreen({super.key, required this.marketId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final async = ref.watch(adminMarketByIdProvider(marketId));
    return Scaffold(
      appBar: AppBar(title: Text(t.adminManageMarkets)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24),
            child: Text(t.failedPrefix(e.toString())))),
        data: (m) => _Body(market: m),
      ),
    );
  }
}


class _Body extends ConsumerWidget {
  final AdminMarket market;
  const _Body({required this.market});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final listings = ref.watch(adminMarketListingsProvider(market.slug));

    return RefreshIndicator(onRefresh: () async {
      ref.invalidate(adminMarketByIdProvider(market.id));
      ref.invalidate(adminMarketListingsProvider(market.slug));
    }, child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 32), children: [
      // ---- Identity card ----
      Container(
        decoration: BoxDecoration(color: cs.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5), width: 0.5)),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(market.nameUz, style: tt.titleLarge),
          if (market.nameRu.isNotEmpty && market.nameRu != market.nameUz) Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(market.nameRu, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant))),
          const SizedBox(height: 12),
          _IconRow(icon: Icons.place_outlined,
              text: '${market.region}${market.address.isNotEmpty ? " · ${market.address}" : ""}'),
          if (market.phone.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8),
            child: _IconRow(icon: Icons.phone_outlined, text: market.phone)),
          if (!market.isActive) Padding(padding: const EdgeInsets.only(top: 8),
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: cs.errorContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(999)),
              child: Text('archived', style: tt.labelSmall?.copyWith(color: cs.onErrorContainer)))),
        ]),
      ),
      const SizedBox(height: 12),
      // ---- Edit + Delete actions ----
      Row(children: [
        Expanded(child: OutlinedButton.icon(
          icon: const Icon(Icons.edit_outlined),
          label: Text(t.adminMarketEditCta),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
          onPressed: () async {
            final saved = await editMarketDialog(context, ref, market);
            if (saved == true) ref.invalidate(adminMarketByIdProvider(market.id));
          },
        )),
        const SizedBox(width: 12),
        Expanded(child: OutlinedButton.icon(
          icon: Icon(Icons.delete_outline, color: cs.error),
          label: Text(t.adminMarketDeleteCta, style: TextStyle(color: cs.error)),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44),
              side: BorderSide(color: cs.error.withValues(alpha: 0.5))),
          onPressed: () async {
            await deleteMarketConfirm(context, ref, market);
            // Soft-delete keeps the row but flips is_active — pop so the list reflects the change.
            if (context.mounted) context.pop();
          },
        )),
      ]),
      const SizedBox(height: 28),
      // ---- Listings header ----
      Padding(padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(t.adminMarketDetailListings, style: tt.titleSmall?.copyWith(
            color: cs.onSurfaceVariant, letterSpacing: 0.4, fontWeight: FontWeight.w600))),
      // ---- Listings list ----
      listings.when(
        loading: () => const Padding(padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Padding(padding: const EdgeInsets.all(16),
            child: Text(t.failedPrefix(e.toString()), style: TextStyle(color: cs.error))),
        data: (rows) => rows.isEmpty
          ? Padding(padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text(t.adminMarketEmpty,
                  style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant))))
          : Container(
              decoration: BoxDecoration(color: cs.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5), width: 0.5)),
              child: Column(children: [
                for (int i = 0; i < rows.length; i++) ...[
                  ListTile(
                    title: Text(rows[i].nameUz, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                        '${rows[i].pricePerKg.toStringAsFixed(0)} so\'m / kg · ${rows[i].status.name}',
                        style: TextStyle(color: cs.onSurfaceVariant)),
                    trailing: const Icon(Icons.chevron_right),
                    // Admin tap → admin edit screen (NOT the buyer-side detail). Edit screen handles
                    // photo CRUD + status + delete, then pops back so this market's listings refresh.
                    onTap: () => context.push('/admin/listings/${rows[i].id}'),
                  ),
                  if (i < rows.length - 1) Padding(padding: const EdgeInsets.only(left: 16),
                    child: Divider(height: 0.5, color: cs.outlineVariant.withValues(alpha: 0.5))),
                ],
              ])),
      ),
    ]));
  }
}


class _IconRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _IconRow({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(children: [
      Icon(icon, size: 18, color: cs.onSurfaceVariant),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: tt.bodyMedium)),
    ]);
  }
}
