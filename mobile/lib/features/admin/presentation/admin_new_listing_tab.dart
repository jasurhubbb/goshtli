// AdminNewListingTab — full form for creating a listing for a chosen Bozor (Market).
//
// v3.3 redesign:
//   • Supplier picker REMOVED — backend resolves Listing.supplier from Market.owner_user, so admin only
//     picks a Bozor. The "Bozor == supplier" model lives entirely on the backend; the UI sees one concept.
//   • available_from picker REMOVED — backend defaults to today(); buyers don't filter on it for fresh meat.
//   • Image picker ADDED — gallery + camera; multi-photo support via image_picker. Photos upload after the
//     listing is created (POST /listings/<id>/photos/ — backend admin bypass is in place).
//
// Required fields the form still collects:
//   • Bozor — dropdown from /markets/
//   • Category — dropdown from /categories/
//   • name_uz / name_ru — bilingual product name (server requires both)
//   • quantity_kg / price_per_kg — decimals; sent as strings to match the Listing wire format
//   • At least one photo (server doesn't require, but listings without photos render poorly so we enforce here)
//   • description_uz / description_ru — optional
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../l10n/app_localizations.dart';
import '../../listings/data/listings_repository.dart';
import '../../listings/providers/listings_providers.dart';
import '../providers/admin_providers.dart';


class AdminNewListingTab extends ConsumerStatefulWidget {
  const AdminNewListingTab({super.key});
  @override
  ConsumerState<AdminNewListingTab> createState() => _AdminNewListingTabState();
}


class _AdminNewListingTabState extends ConsumerState<AdminNewListingTab> {
  // Selected FK ids — populated from the dropdowns once the futures resolve.
  int? _marketId, _categoryId;
  // Text controllers — shared dispose loop keeps the boilerplate compact.
  final _nameUz = TextEditingController();
  final _nameRu = TextEditingController();
  final _quantity = TextEditingController();
  final _price = TextEditingController();
  final _location = TextEditingController();
  final _descUz = TextEditingController();
  final _descRu = TextEditingController();
  // Photos staged for upload. XFile cross-platforms file refs so we don't fight with dart:io on web.
  final List<XFile> _pickedPhotos = [];
  final _picker = ImagePicker();
  bool _submitting = false;
  String? _err;

  @override
  void dispose() {
    for (final c in [_nameUz, _nameRu, _quantity, _price, _location, _descUz, _descRu]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Bottom-sheet picker — Galereya vs Kamera. Returns one image; users tap "+ Rasm qo'shish" repeatedly
  /// to add multiple. Keeps the action sheet predictable instead of opening a multi-select straight away.
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
    // Limit pixel size — server resizes via Celery (apps/listings/tasks.py), but capping at 2000px on the
    // client cuts upload bytes by ~10x for typical phone-camera 4032×3024 shots.
    final picked = await _picker.pickImage(source: source, maxWidth: 2000, maxHeight: 2000, imageQuality: 85);
    if (picked != null && mounted) setState(() => _pickedPhotos.add(picked));
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context);
    if (_marketId == null || _categoryId == null) {
      setState(() => _err = t.validateRequired);
      return;
    }
    final qty = double.tryParse(_quantity.text);
    final price = double.tryParse(_price.text);
    if (qty == null || price == null || qty <= 0 || price <= 0
        || _nameUz.text.trim().isEmpty || _nameRu.text.trim().isEmpty) {
      setState(() => _err = t.validateRequired);
      return;
    }
    if (_pickedPhotos.isEmpty) {
      setState(() => _err = t.photoRequired);
      return;
    }
    setState(() { _submitting = true; _err = null; });
    try {
      final created = await ref.read(adminRepositoryProvider).createListing(
        marketId: _marketId!, categoryId: _categoryId!,
        nameUz: _nameUz.text.trim(), nameRu: _nameRu.text.trim(),
        quantityKg: qty, pricePerKg: price,
        location: _location.text.trim(),
        descriptionUz: _descUz.text.trim(), descriptionRu: _descRu.text.trim(),
      );
      // Upload each photo sequentially — keep the order stable (backend assigns position=0,1,2... in arrival order).
      final listingId = (created['id'] as num).toInt();
      for (final p in _pickedPhotos) {
        await ref.read(adminRepositoryProvider).uploadListingPhoto(listingId, p.path);
      }
      // Buyer-side listings cache is stale now — invalidate so the home grid shows the new row on next render.
      ref.invalidate(activeListingsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.adminListingCreated)));
      // Clear volatile inputs — keep Bozor + Category picks since admin often batches "5 listings for one market".
      for (final c in [_nameUz, _nameRu, _quantity, _price, _location, _descUz, _descRu]) { c.clear(); }
      setState(() => _pickedPhotos.clear());
    } on ApiException catch (e) {
      // 403 here would mean the admin-unlock JWT was lost — surface a friendlier message.
      final msg = e.message.toLowerCase().contains('permission')
          ? t.adminPermissionDenied : e.message;
      if (mounted) setState(() => _err = msg);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final markets = ref.watch(adminMarketsProvider);
    final categories = ref.watch(adminCategoriesProvider);

    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
      // ---- Photos (top of form — sets expectation that listings need images) ----
      Text(t.adminNewListingPhotos, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
      const SizedBox(height: 8),
      _PhotoStrip(photos: _pickedPhotos, onAdd: _pickPhoto,
          onRemove: (i) => setState(() => _pickedPhotos.removeAt(i))),
      const SizedBox(height: 20),
      // ---- Bozor (market) picker ----
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
            for (final m in list.where((m) => m.isActive)) DropdownMenuItem(value: m.id,
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
      // ---- Bilingual name (both required) ----
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
      // ---- Free-text location override (optional; usually inherits from market.address) ----
      TextField(controller: _location, decoration: InputDecoration(
          labelText: '${t.listingFieldLocation} (${t.listingFieldDescriptionOptional.toLowerCase()})',
          border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      // ---- Optional bilingual descriptions ----
      TextField(controller: _descUz, maxLines: 3, decoration: InputDecoration(
          labelText: '${t.listingFieldDescriptionOptional} (UZ)', border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: _descRu, maxLines: 3, decoration: InputDecoration(
          labelText: '${t.listingFieldDescriptionOptional} (RU)', border: const OutlineInputBorder())),
      const SizedBox(height: 16),
      if (_err != null) Padding(padding: const EdgeInsets.only(bottom: 8),
          child: Text(_err!, style: TextStyle(color: cs.error))),
      // ---- Submit ----
      FilledButton(onPressed: _submitting ? null : _submit,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        child: _submitting
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(t.adminNewListingSubmit)),
    ]);
  }
}


/// Horizontal strip of staged photos + an "add" tile at the end. Each photo has an x-button overlay.
/// Lives inside this file (rather than shared/widgets) because it's tightly coupled to the new-listing
/// form's lifecycle — moving it would require a Riverpod state object for the photo list.
class _PhotoStrip extends StatelessWidget {
  final List<XFile> photos;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;
  const _PhotoStrip({required this.photos, required this.onAdd, required this.onRemove});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(height: 96, child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: photos.length + 1,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        if (i == photos.length) {
          // "Add photo" tile — dashed border + plus icon
          return InkWell(onTap: onAdd, borderRadius: BorderRadius.circular(12), child: Container(
            width: 96, height: 96,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant, width: 1.2, style: BorderStyle.solid)),
            child: Icon(Icons.add_a_photo_outlined, color: cs.onSurfaceVariant)));
        }
        return Stack(clipBehavior: Clip.none, children: [
          ClipRRect(borderRadius: BorderRadius.circular(12),
            child: Image.file(File(photos[i].path), width: 96, height: 96, fit: BoxFit.cover)),
          Positioned(top: -6, right: -6, child: Material(color: Colors.transparent,
            child: InkWell(borderRadius: BorderRadius.circular(999), onTap: () => onRemove(i),
              child: Container(padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: cs.surface, shape: BoxShape.circle,
                    border: Border.all(color: cs.outlineVariant)),
                child: Icon(Icons.close, size: 16, color: cs.onSurface))))),
        ]);
      }));
  }
}
