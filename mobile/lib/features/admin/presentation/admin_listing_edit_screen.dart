// AdminListingEditScreen — full edit form for an existing listing.
//
// Reached from two places:
//   • Boshqarish > E'lonlar > tap a listing
//   • Boshqarish > Bozorlar > tap a Bozor > tap a listing
//
// Layout mirrors the new-listing tab (Bozor + Category dropdowns, bilingual name, qty/price, location,
// descriptions, photos). On top of that:
//   • Status segmented selector (ACTIVE / OUT_OF_STOCK / ARCHIVED) — admin's most common edit
//   • Existing photos rendered first with delete buttons; new photos can be appended and upload on save
//   • Delete listing button at the bottom (red) — server refuses if orders are attached; we surface that
//
// Like the new-listing tab, success drops a 1s green top toast and pops back so the parent list refreshes.
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../l10n/app_localizations.dart';
import '../../listings/data/listings_repository.dart';
import '../../listings/providers/listings_providers.dart';
import '../providers/admin_providers.dart';
import 'admin_market_detail_screen.dart' show adminMarketListingsProvider;


/// Single-listing fetch keyed by id; autoDispose so leaving the edit screen drops the cache and a re-entry
/// pulls fresh state (admin may have edited from another device, etc.).
final adminListingByIdProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, int>((ref, id) =>
        ref.watch(adminRepositoryProvider).getListing(id));


class AdminListingEditScreen extends ConsumerWidget {
  final int listingId;
  const AdminListingEditScreen({super.key, required this.listingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final async = ref.watch(adminListingByIdProvider(listingId));
    return Scaffold(
      appBar: AppBar(title: Text(t.adminListingEditTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24),
            child: Text(t.failedPrefix(e.toString())))),
        data: (json) => _EditForm(initial: json, listingId: listingId),
      ),
    );
  }
}


class _EditForm extends ConsumerStatefulWidget {
  final Map<String, dynamic> initial;
  final int listingId;
  const _EditForm({required this.initial, required this.listingId});
  @override
  ConsumerState<_EditForm> createState() => _EditFormState();
}


class _EditFormState extends ConsumerState<_EditForm> {
  late int? _marketId, _categoryId;
  late final TextEditingController _nameUz, _nameRu, _quantity, _price, _location, _descUz, _descRu;
  late String _status;                                                     // ACTIVE / OUT_OF_STOCK / ARCHIVED
  late List<Map<String, dynamic>> _existingPhotos;                         // {id, url, position}
  final List<XFile> _newPhotos = [];                                       // staged for upload on save
  final _picker = ImagePicker();
  bool _saving = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    final j = widget.initial;
    // market + category nested on read; ids come from the nested object
    _marketId = (j['market'] as Map?)?['id'] as int?;
    // Category nested has no id field on the buyer wire shape — re-find by slug from the categories provider
    // after data loads. Stashed as null here; the form's Category dropdown handles null gracefully.
    _categoryId = null;
    _nameUz = TextEditingController(text: j['name_uz'] as String? ?? '');
    _nameRu = TextEditingController(text: j['name_ru'] as String? ?? '');
    _quantity = TextEditingController(text: (j['quantity_kg'] as String? ?? '0').replaceAll(RegExp(r'\.?0+$'), ''));
    _price = TextEditingController(text: (j['price_per_kg'] as String? ?? '0').replaceAll(RegExp(r'\.?0+$'), ''));
    _location = TextEditingController(text: j['location'] as String? ?? '');
    _descUz = TextEditingController(text: j['description_uz'] as String? ?? '');
    _descRu = TextEditingController(text: j['description_ru'] as String? ?? '');
    _status = j['status'] as String? ?? 'ACTIVE';
    _existingPhotos = ((j['photos'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  void dispose() {
    for (final c in [_nameUz, _nameRu, _quantity, _price, _location, _descUz, _descRu]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Picker — same gallery/camera bottom sheet as the new-listing tab.
  Future<void> _pickPhoto() async {
    final t = AppLocalizations.of(context);
    final source = await showModalBottomSheet<ImageSource>(context: context, builder: (sctx) =>
      SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.photo_library_outlined),
            title: Text(t.adminPickFromGallery),
            onTap: () => Navigator.pop(sctx, ImageSource.gallery)),
        ListTile(leading: const Icon(Icons.photo_camera_outlined),
            title: Text(t.adminPickFromCamera),
            onTap: () => Navigator.pop(sctx, ImageSource.camera)),
      ])));
    if (source == null) return;
    final picked = await _picker.pickImage(source: source, maxWidth: 2000, maxHeight: 2000, imageQuality: 85);
    if (picked != null && mounted) setState(() => _newPhotos.add(picked));
  }

  Future<void> _deleteExistingPhoto(Map<String, dynamic> photo) async {
    final t = AppLocalizations.of(context);
    final id = photo['id'] as int;
    try {
      await ref.read(adminRepositoryProvider).deleteListingPhoto(widget.listingId, id);
      setState(() => _existingPhotos.removeWhere((p) => p['id'] == id));
    } catch (e, st) {
      debugPrint('[AdminListingEditScreen] deletePhoto failed: $e\n$st');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_humanError(e, t))));
    }
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    final qty = double.tryParse(_quantity.text);
    final price = double.tryParse(_price.text);
    if (qty == null || price == null || qty <= 0 || price <= 0
        || _nameUz.text.trim().isEmpty || _nameRu.text.trim().isEmpty) {
      setState(() => _err = t.validateRequired);
      return;
    }
    setState(() { _saving = true; _err = null; });
    try {
      await ref.read(adminRepositoryProvider).patchListing(
        widget.listingId,
        marketId: _marketId, categoryId: _categoryId,
        nameUz: _nameUz.text.trim(), nameRu: _nameRu.text.trim(),
        descriptionUz: _descUz.text.trim(), descriptionRu: _descRu.text.trim(),
        quantityKg: qty, pricePerKg: price,
        location: _location.text.trim(),
        status: _status,
      );
      // Upload any new photos. Soft-fail on individual photo errors — the listing edit itself already saved.
      final List<String> photoErrors = [];
      for (final p in _newPhotos) {
        try {
          await ref.read(adminRepositoryProvider).uploadListingPhoto(widget.listingId, p.path);
        } catch (e, st) {
          debugPrint('[AdminListingEditScreen] photo upload failed: $e\n$st');
          photoErrors.add(e.toString());
        }
      }
      // Refresh the caches anyone might be viewing — home grid, admin's market detail, the listing itself.
      ref.invalidate(activeListingsProvider);
      ref.invalidate(adminListingByIdProvider(widget.listingId));
      final m = widget.initial['market'] as Map?;
      if (m != null && m['slug'] is String) {
        ref.invalidate(adminMarketListingsProvider(m['slug'] as String));
      }
      if (!mounted) return;
      _showTopSuccessToast(context, photoErrors.isEmpty
          ? t.adminListingSavedToast
          : '${t.adminListingSavedToast} (${photoErrors.length} photo upload(s) failed)');
      context.pop();
    } catch (e, st) {
      debugPrint('[AdminListingEditScreen] save failed: $e\n$st');
      final msg = _humanError(e, t);
      if (mounted) {
        setState(() => _err = msg);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(context: context, builder: (dctx) => AlertDialog(
      title: Text(t.adminListingDeleteCta),
      content: Text(t.deleteAccountConfirmBody),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dctx, false), child: Text(t.no)),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Theme.of(dctx).colorScheme.error),
            onPressed: () => Navigator.pop(dctx, true), child: Text(t.adminListingDeleteCta)),
      ]));
    if (ok != true) return;
    try {
      await ref.read(adminRepositoryProvider).deleteListing(widget.listingId);
      ref.invalidate(activeListingsProvider);
      final m = widget.initial['market'] as Map?;
      if (m != null && m['slug'] is String) {
        ref.invalidate(adminMarketListingsProvider(m['slug'] as String));
      }
      if (mounted) context.pop();
    } catch (e, st) {
      // Backend refuses delete when orders exist — surface the message so admin knows to ARCHIVE instead.
      debugPrint('[AdminListingEditScreen] delete failed: $e\n$st');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_humanError(e, t))));
    }
  }

  /// Same shape as the new-listing tab's helper — translate any thrown object into a one-liner the
  /// admin can act on, instead of letting a DioException toString leak to the UI.
  String _humanError(Object e, AppLocalizations t) {
    if (e is ApiException) {
      if (e.message.toLowerCase().contains('permission')) return t.adminPermissionDenied;
      return e.message;
    }
    if (e is DioException) {
      final code = e.response?.statusCode;
      final detail = e.response?.data is Map ? e.response!.data['detail'] : null;
      if (code == 401 || code == 403) return t.adminPermissionDenied;
      if (detail is String) return detail;
      if (code != null) return 'HTTP $code';
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
        return 'Network timeout — check your connection';
      }
      return e.message ?? 'Network error';
    }
    if (e is FileSystemException) return 'Photo file could not be read — pick the photos again';
    return e.toString();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final markets = ref.watch(adminMarketsProvider);
    final categories = ref.watch(adminCategoriesProvider);

    // First time the categories list resolves, find the id matching the current listing's slug so the
    // Category dropdown shows the right pre-selection. We can't do this in initState because the provider
    // is async.
    categories.whenData((list) {
      if (_categoryId != null) return;
      final slug = (widget.initial['category'] as Map?)?['slug'] as String?;
      if (slug == null) return;
      final match = list.where((c) => c.slug == slug).toList();
      if (match.isNotEmpty) {
        // Schedule for next frame to avoid setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _categoryId = match.first.id);
        });
      }
    });

    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
      // ---- Photos: existing first, then "add" tile ----
      Text(t.adminNewListingPhotos, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
      const SizedBox(height: 8),
      _EditPhotoStrip(
        existing: _existingPhotos, staged: _newPhotos,
        onAdd: _pickPhoto,
        onRemoveExisting: _deleteExistingPhoto,
        onRemoveStaged: (i) => setState(() => _newPhotos.removeAt(i)),
      ),
      const SizedBox(height: 20),
      // ---- Status segmented (ACTIVE / OUT_OF_STOCK / ARCHIVED) ----
      Text(t.listingFieldStatus, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
      const SizedBox(height: 6),
      SegmentedButton<String>(
        segments: [
          ButtonSegment(value: 'ACTIVE', label: Text(t.statusActive)),
          ButtonSegment(value: 'OUT_OF_STOCK', label: Text(t.statusSoldOut)),
          ButtonSegment(value: 'ARCHIVED', label: Text(t.statusInactive)),
        ],
        selected: {_status},
        onSelectionChanged: (s) => setState(() => _status = s.first),
        showSelectedIcon: false,
      ),
      const SizedBox(height: 16),
      // ---- Bozor picker ----
      Text(t.adminManageMarkets, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
      const SizedBox(height: 6),
      markets.when(
        loading: () => const LinearProgressIndicator(minHeight: 2),
        error: (e, _) => Text(t.failedPrefix(e.toString()), style: TextStyle(color: cs.error)),
        data: (list) => DropdownButtonFormField<int>(
          initialValue: _marketId,
          isExpanded: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: [
            for (final m in list) DropdownMenuItem(value: m.id,
              child: Text('${m.nameUz} · ${m.region}', overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => setState(() => _marketId = v),
        ),
      ),
      const SizedBox(height: 16),
      // ---- Category picker ----
      Text(t.listingFieldMeatType, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
      const SizedBox(height: 6),
      categories.when(
        loading: () => const LinearProgressIndicator(minHeight: 2),
        error: (e, _) => Text(t.failedPrefix(e.toString()), style: TextStyle(color: cs.error)),
        data: (list) => DropdownButtonFormField<int>(
          initialValue: _categoryId,
          isExpanded: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: [
            for (final c in list.where((c) => c.isActive)) DropdownMenuItem(value: c.id,
              child: Text(c.nameUz, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => setState(() => _categoryId = v),
        ),
      ),
      const SizedBox(height: 16),
      // ---- Bilingual name ----
      TextField(controller: _nameUz, decoration: InputDecoration(
          labelText: '${t.listingFieldTitle} (UZ)', border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: _nameRu, decoration: InputDecoration(
          labelText: '${t.listingFieldTitle} (RU)', border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      // ---- Quantity + price ----
      Row(children: [
        Expanded(child: TextField(controller: _quantity, keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: t.listingFieldQuantity, border: const OutlineInputBorder()))),
        const SizedBox(width: 12),
        Expanded(child: TextField(controller: _price, keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: t.listingFieldPricePerKg, border: const OutlineInputBorder()))),
      ]),
      const SizedBox(height: 12),
      TextField(controller: _location, decoration: InputDecoration(
          labelText: '${t.listingFieldLocation} (${t.listingFieldDescriptionOptional.toLowerCase()})',
          border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: _descUz, maxLines: 3, decoration: InputDecoration(
          labelText: '${t.listingFieldDescriptionOptional} (UZ)', border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: _descRu, maxLines: 3, decoration: InputDecoration(
          labelText: '${t.listingFieldDescriptionOptional} (RU)', border: const OutlineInputBorder())),
      const SizedBox(height: 16),
      if (_err != null) Padding(padding: const EdgeInsets.only(bottom: 8),
          child: Text(_err!, style: TextStyle(color: cs.error))),
      // ---- Save ----
      FilledButton(onPressed: _saving ? null : _save,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        child: _saving
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(t.listingActionSave)),
      const SizedBox(height: 20),
      // ---- Destructive: Delete listing ----
      OutlinedButton.icon(
        icon: Icon(Icons.delete_outline, color: cs.error),
        label: Text(t.adminListingDeleteCta, style: TextStyle(color: cs.error)),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44),
            side: BorderSide(color: cs.error.withValues(alpha: 0.5))),
        onPressed: _saving ? null : _delete,
      ),
    ]);
  }
}


/// Edit-screen photo strip — renders existing server-side photos first (with x to call DELETE), then any
/// newly-staged XFiles (with x to drop locally), then the "add" tile.
class _EditPhotoStrip extends StatelessWidget {
  final List<Map<String, dynamic>> existing;
  final List<XFile> staged;
  final VoidCallback onAdd;
  final Future<void> Function(Map<String, dynamic>) onRemoveExisting;
  final void Function(int index) onRemoveStaged;
  const _EditPhotoStrip({required this.existing, required this.staged, required this.onAdd,
      required this.onRemoveExisting, required this.onRemoveStaged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totalTiles = existing.length + staged.length + 1;       // +1 for the "add" tile
    return SizedBox(height: 96, child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: totalTiles,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        if (i == totalTiles - 1) {
          // Trailing "+" tile
          return InkWell(onTap: onAdd, borderRadius: BorderRadius.circular(12), child: Container(
            width: 96, height: 96,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant, width: 1.2)),
            child: Icon(Icons.add_a_photo_outlined, color: cs.onSurfaceVariant)));
        }
        // First N tiles → existing server-side photos. After that → staged-but-not-uploaded new photos.
        if (i < existing.length) {
          final p = existing[i];
          return Stack(clipBehavior: Clip.none, children: [
            ClipRRect(borderRadius: BorderRadius.circular(12),
              child: Image.network(p['url'] as String, width: 96, height: 96, fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(width: 96, height: 96, color: cs.surfaceContainerHighest,
                    child: Icon(Icons.broken_image_outlined, color: cs.onSurfaceVariant)))),
            Positioned(top: -6, right: -6, child: _RemoveButton(onTap: () => onRemoveExisting(p))),
          ]);
        }
        final s = staged[i - existing.length];
        return Stack(clipBehavior: Clip.none, children: [
          ClipRRect(borderRadius: BorderRadius.circular(12),
            child: Image.file(File(s.path), width: 96, height: 96, fit: BoxFit.cover)),
          Positioned(top: -6, right: -6, child: _RemoveButton(
              onTap: () => onRemoveStaged(i - existing.length))),
        ]);
      }));
  }
}


class _RemoveButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RemoveButton({required this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(999),
      onTap: onTap, child: Container(padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: cs.surface, shape: BoxShape.circle,
            border: Border.all(color: cs.outlineVariant)),
        child: Icon(Icons.close, size: 16, color: cs.onSurface))));
  }
}


/// 1s green top toast — same helper shape as admin_new_listing_tab's _showTopSuccessToast. Duplicated here
/// rather than extracted into a shared widget because the file count is already high; if a third call site
/// shows up we'll hoist it.
void _showTopSuccessToast(BuildContext context, String message) {
  final overlay = Overlay.of(context);
  final entry = OverlayEntry(builder: (octx) {
    final tt = Theme.of(octx).textTheme;
    return Positioned(
      top: MediaQuery.of(octx).padding.top + 8,
      left: 16, right: 16,
      child: Material(color: Colors.transparent, child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: const Color(0xFF2E7D32),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8, offset: const Offset(0, 2))]),
        child: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: tt.bodyMedium?.copyWith(
              color: Colors.white, fontWeight: FontWeight.w500))),
        ]),
      )),
    );
  });
  overlay.insert(entry);
  Future.delayed(const Duration(milliseconds: 1100), entry.remove);
}
