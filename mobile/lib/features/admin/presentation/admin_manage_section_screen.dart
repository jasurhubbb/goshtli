// Admin "Boshqarish" sub-section screens — one dispatcher widget that renders the right list+edit UI
// depending on the AdminSection enum value, plus four specialized widgets (Listings/Suppliers/Categories/Markets).
//
// Kept in one file because the four UIs are structurally identical (list → tap to edit → save), and splitting
// them would duplicate the ListView+RefreshIndicator scaffolding three times. Each section pulls its own
// Riverpod provider, so re-renders stay scoped to the section being viewed.
//
// Listings sub-section reuses the existing /listings/<id> screen for edit, since IsListingOwnerOrReadOnly now
// honors ADMIN role — admin's edits flow through the same code path suppliers use.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../listings/data/listings_repository.dart';
import '../../listings/providers/listings_providers.dart';
import '../data/admin_models.dart';
import '../providers/admin_providers.dart';
import 'admin_screen.dart' show AdminSection;


class AdminManageSectionScreen extends ConsumerWidget {
  final AdminSection section;
  const AdminManageSectionScreen({super.key, required this.section});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final title = switch (section) {
      AdminSection.listings => t.adminManageListings,
      AdminSection.categories => t.adminManageCategories,
      AdminSection.markets => t.adminManageMarkets,
    };
    final body = switch (section) {
      AdminSection.listings => const _ListingsSection(),
      AdminSection.categories => const _CategoriesSection(),
      AdminSection.markets => const _MarketsSection(),
    };
    return Scaffold(appBar: AppBar(title: Text(title)), body: body);
  }
}


// ---------- Listings ----------------------------------------------------------

/// All listings (every status) — tap opens the existing detail screen which supports admin edit because
/// IsListingOwnerOrReadOnly now lets ADMIN role mutate any listing.
class _ListingsSection extends ConsumerWidget {
  const _ListingsSection();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    // Pull EVERY listing regardless of status. The browse provider's default filters hide archived/out-of-stock;
    // for admin we want the whole table. We override by reading directly through the repo here.
    final async = ref.watch(_adminAllListingsProvider);
    return RefreshIndicator(onRefresh: () async => ref.invalidate(_adminAllListingsProvider),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(message: e.toString(), retryLabel: t.refresh,
            onRetry: () => ref.invalidate(_adminAllListingsProvider)),
        data: (rows) => rows.isEmpty
          ? _EmptyView(label: t.noListingsMatchFilters)
          : ListView.separated(itemCount: rows.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final l = rows[i];
                return ListTile(
                  title: Text(l.nameUz, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${l.supplierEmail} · ${l.pricePerKg.toStringAsFixed(0)} so\'m / kg',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  trailing: _StatusPill(status: l.status.name),
                  // Admin tap → admin edit screen (NOT the buyer detail). Edit screen handles status,
                  // photo CRUD, and delete; falls back to the parent list on pop.
                  onTap: () => context.push('/admin/listings/${l.id}'),
                );
              }),
      ));
  }
}


// ---------- Categories --------------------------------------------------------

class _CategoriesSection extends ConsumerWidget {
  const _CategoriesSection();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final async = ref.watch(adminCategoriesProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton(child: const Icon(Icons.add),
        onPressed: () => _editCategoryDialog(context, ref, null)),
      body: RefreshIndicator(onRefresh: () async => ref.invalidate(adminCategoriesProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorView(message: e.toString(), retryLabel: t.refresh,
              onRetry: () => ref.invalidate(adminCategoriesProvider)),
          data: (rows) => ListView.separated(itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final c = rows[i];
              return ListTile(
                title: Text(c.nameUz),
                subtitle: Text('${c.nameRu} · order=${c.displayOrder} · ${c.isActive ? "active" : "archived"}',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                trailing: Wrap(spacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  IconButton(icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _editCategoryDialog(context, ref, c)),
                  IconButton(icon: Icon(Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error),
                      onPressed: () => _deleteCategoryConfirm(context, ref, c)),
                ]),
              );
            }),
        )));
  }

  Future<void> _editCategoryDialog(BuildContext context, WidgetRef ref, AdminCategory? c) async {
    final t = AppLocalizations.of(context);
    final uz = TextEditingController(text: c?.nameUz ?? '');
    final ru = TextEditingController(text: c?.nameRu ?? '');
    final order = TextEditingController(text: (c?.displayOrder ?? 100).toString());
    String? err;
    final saved = await showDialog<bool>(context: context, builder: (dctx) =>
      StatefulBuilder(builder: (dctx, setSt) => AlertDialog(
        title: Text(c == null ? t.adminManageCategories : t.profileTapToEdit),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: uz, decoration: const InputDecoration(labelText: 'name_uz')),
          TextField(controller: ru, decoration: const InputDecoration(labelText: 'name_ru')),
          TextField(controller: order, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'display_order')),
          if (err != null) Padding(padding: const EdgeInsets.only(top: 8),
              child: Text(err!, style: TextStyle(color: Theme.of(dctx).colorScheme.error))),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx, false), child: Text(t.cancel)),
          FilledButton(onPressed: () async {
            try {
              if (c == null) {
                await ref.read(adminRepositoryProvider).createCategory(
                    nameUz: uz.text.trim(), nameRu: ru.text.trim(),
                    displayOrder: int.tryParse(order.text) ?? 100);
              } else {
                await ref.read(adminRepositoryProvider).patchCategory(c.id,
                    nameUz: uz.text.trim(), nameRu: ru.text.trim(),
                    displayOrder: int.tryParse(order.text) ?? c.displayOrder);
              }
              if (dctx.mounted) Navigator.pop(dctx, true);
            } on ApiException catch (e) { setSt(() => err = e.message); }
          }, child: Text(t.listingActionSave)),
        ])));
    if (saved == true) ref.invalidate(adminCategoriesProvider);
  }

  Future<void> _deleteCategoryConfirm(BuildContext context, WidgetRef ref, AdminCategory c) async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(context: context, builder: (dctx) => AlertDialog(
      content: Text('${c.nameUz} — ${t.addressDeleteConfirm}'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dctx, false), child: Text(t.no)),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Theme.of(dctx).colorScheme.error),
            onPressed: () => Navigator.pop(dctx, true), child: Text(t.addressDeleteCta)),
      ]));
    if (ok != true) return;
    try {
      await ref.read(adminRepositoryProvider).deleteCategory(c.id);
      ref.invalidate(adminCategoriesProvider);
    } on ApiException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}


// ---------- Markets ----------------------------------------------------------

class _MarketsSection extends ConsumerWidget {
  const _MarketsSection();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final async = ref.watch(adminMarketsProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton(child: const Icon(Icons.add),
        onPressed: () => editMarketDialog(context, ref, null)),
      body: RefreshIndicator(onRefresh: () async => ref.invalidate(adminMarketsProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorView(message: e.toString(), retryLabel: t.refresh,
              onRetry: () => ref.invalidate(adminMarketsProvider)),
          data: (rows) => ListView.separated(itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final m = rows[i];
              // Whole row is now tappable — opens the Bozor detail screen with its listings + edit. The
              // pencil-edit icon went away because the detail screen has a prominent Tahrirlash button.
              return ListTile(
                title: Text(m.nameUz),
                subtitle: Text('${m.region} · ${m.address}',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/admin/markets/${m.id}'),
              );
            }),
        )));
  }
}


/// Edit-or-create market dialog — public so the Bozor detail screen can reuse it for the Tahrirlash button.
/// `m == null` means create; non-null means edit. Returns true to the caller when a save succeeds so the
/// caller can invalidate providers / pop / refresh. Phone is included as a real field per v3.3 spec.
Future<bool?> editMarketDialog(BuildContext context, WidgetRef ref, AdminMarket? m) async {
  final t = AppLocalizations.of(context);
  final uz = TextEditingController(text: m?.nameUz ?? '');
  final ru = TextEditingController(text: m?.nameRu ?? '');
  final region = TextEditingController(text: m?.region ?? '');
  final addr = TextEditingController(text: m?.address ?? '');
  // Phone is the Bozor's contact number — separate from any User.phone; backend stores it on the Market row.
  // Phone is the Bozor's contact number — stored on the Market row (NOT mirrored to the synthetic owner User
  // to keep that user out of phone-login). Prefilled from the AdminMarket on edit.
  final phone = TextEditingController(text: m?.phone ?? '');
  String? err;
  final saved = await showDialog<bool>(context: context, builder: (dctx) =>
    StatefulBuilder(builder: (dctx, setSt) => AlertDialog(
      title: Text(m == null ? t.adminManageMarkets : t.profileTapToEdit),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: uz, decoration: const InputDecoration(labelText: 'name_uz')),
        TextField(controller: ru, decoration: const InputDecoration(labelText: 'name_ru')),
        TextField(controller: region, decoration: const InputDecoration(labelText: 'region')),
        TextField(controller: addr, decoration: const InputDecoration(labelText: 'address')),
        TextField(controller: phone, keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'phone (+998...)', hintText: '+998901234567')),
        if (err != null) Padding(padding: const EdgeInsets.only(top: 8),
            child: Text(err!, style: TextStyle(color: Theme.of(dctx).colorScheme.error))),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dctx, false), child: Text(t.cancel)),
        FilledButton(onPressed: () async {
          try {
            if (m == null) {
              await ref.read(adminRepositoryProvider).createMarket(
                  nameUz: uz.text.trim(), nameRu: ru.text.trim(),
                  region: region.text.trim(), address: addr.text.trim(),
                  phone: phone.text.trim());
            } else {
              await ref.read(adminRepositoryProvider).patchMarket(m.id,
                  nameUz: uz.text.trim(), nameRu: ru.text.trim(),
                  region: region.text.trim(), address: addr.text.trim(),
                  phone: phone.text.trim());
            }
            if (dctx.mounted) Navigator.pop(dctx, true);
          } on ApiException catch (e) { setSt(() => err = e.message); }
        }, child: Text(t.listingActionSave)),
      ])));
  if (saved == true) ref.invalidate(adminMarketsProvider);
  return saved;
}


/// Soft-delete a market — confirms first, then DELETEs (which the backend turns into is_active=false to
/// preserve FK integrity). Used from the Bozor detail screen's Tahrirlash menu.
Future<void> deleteMarketConfirm(BuildContext context, WidgetRef ref, AdminMarket m) async {
  final t = AppLocalizations.of(context);
  final ok = await showDialog<bool>(context: context, builder: (dctx) => AlertDialog(
    content: Text('${m.nameUz} — ${t.addressDeleteConfirm}'),
    actions: [
      TextButton(onPressed: () => Navigator.pop(dctx, false), child: Text(t.no)),
      FilledButton(style: FilledButton.styleFrom(backgroundColor: Theme.of(dctx).colorScheme.error),
          onPressed: () => Navigator.pop(dctx, true), child: Text(t.addressDeleteCta)),
    ]));
  if (ok != true) return;
  try {
    await ref.read(adminRepositoryProvider).deleteMarket(m.id);
    ref.invalidate(adminMarketsProvider);
  } on ApiException catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(e.message)));
  }
}


// ---------- Shared bits ------------------------------------------------------

/// Admin-side listings fetch — pulls EVERY status. v3.3: backend's get_queryset is admin-aware (skips the
/// ACTIVE-only default when request.user.is_admin_role), so we just hit /listings/ without a status filter
/// and let the server send back the full table. The earlier "pass comma-separated statuses" approach was
/// rejected by django-filter's ChoiceFilter (only single values match the choices list).
final _adminAllListingsProvider = FutureProvider.autoDispose((ref) async {
  final repo = ref.watch(listingsRepositoryProvider);
  final page = await repo.browse(ordering: '-created_at');
  return page.results;
});


class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = switch (status.toUpperCase()) {
      'ACTIVE' => cs.primary,
      'OUT_OF_STOCK' => cs.tertiary,
      _ => cs.outline,
    };
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999)),
      child: Text(status, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)));
  }
}


class _ErrorView extends StatelessWidget {
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.retryLabel, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(message, textAlign: TextAlign.center),
      const SizedBox(height: 12),
      OutlinedButton(onPressed: onRetry, child: Text(retryLabel)),
    ])));
}


class _EmptyView extends StatelessWidget {
  final String label;
  const _EmptyView({required this.label});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24),
    child: Text(label, style: Theme.of(context).textTheme.bodyLarge,
        textAlign: TextAlign.center)));
}
