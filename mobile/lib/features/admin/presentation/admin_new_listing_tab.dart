// AdminNewListingTab — full form for creating a listing for a chosen Bozor (Market).
//
// v3.3 redesign:
//   • Supplier picker REMOVED — backend resolves Listing.supplier from Market.owner_user
//   • available_from picker REMOVED — backend defaults to today()
//   • Image picker ADDED — gallery + camera, multi-photo
//
// Production-style feedback (added because the bottom SnackBar + tiny inline error were easy to miss):
//   • Inline animated banner sits at the TOP of the form (above the photos strip)
//   • Slides in with green-success / red-error background, large check/error icon, 2-second auto-dismiss
//   • Haptic feedback on submit complete (medium = success, heavy = error)
//   • Auto-scroll to top after success so admin sees the cleared form + banner together
//   • debugPrint on submit entry so logcat reveals whether the button click is even registering when
//     something feels wrong
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  int? _marketId, _categoryId;
  final _nameUz = TextEditingController();
  final _nameRu = TextEditingController();
  final _quantity = TextEditingController();
  final _price = TextEditingController();
  final _location = TextEditingController();
  final _descUz = TextEditingController();
  final _descRu = TextEditingController();
  final List<XFile> _pickedPhotos = [];
  final _picker = ImagePicker();
  final _scrollCtrl = ScrollController();
  bool _submitting = false;
  // Banner state — `_banner` carries (message, isSuccess) and the inline AnimatedSwitcher reacts to it.
  ({String message, bool success})? _banner;

  @override
  void dispose() {
    for (final c in [_nameUz, _nameRu, _quantity, _price, _location, _descUz, _descRu]) {
      c.dispose();
    }
    _scrollCtrl.dispose();
    super.dispose();
  }

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
    if (picked != null && mounted) setState(() => _pickedPhotos.add(picked));
  }

  /// Display a banner at the top of the form. Auto-dismisses after `duration`.
  void _showBanner(String message, {required bool success, Duration duration = const Duration(seconds: 2)}) {
    if (!mounted) return;
    setState(() => _banner = (message: message, success: success));
    HapticFeedback.mediumImpact();
    // Scroll the form to the top so the user actually sees the banner instead of leaving them at the
    // submit button (where they last tapped). Skip if scroll controller isn't attached yet.
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
    Future.delayed(duration, () {
      if (mounted && _banner?.message == message) setState(() => _banner = null);
    });
  }

  Future<void> _submit() async {
    debugPrint('[AdminNewListingTab] submit tapped; market=$_marketId category=$_categoryId photos=${_pickedPhotos.length}');
    final t = AppLocalizations.of(context);
    // Per-field validation — show the SPECIFIC missing field instead of a vague "required".
    String? missing;
    if (_marketId == null) missing = t.adminManageMarkets;
    else if (_categoryId == null) missing = t.listingFieldMeatType;
    else if (_nameUz.text.trim().isEmpty) missing = '${t.listingFieldTitle} (UZ)';
    else if (_nameRu.text.trim().isEmpty) missing = '${t.listingFieldTitle} (RU)';
    if (missing != null) {
      _showBanner('${t.validateRequired}: $missing', success: false);
      return;
    }
    final qty = double.tryParse(_quantity.text);
    final price = double.tryParse(_price.text);
    if (qty == null || qty <= 0) {
      _showBanner('${t.listingFieldQuantity}: ${t.validateGtZero}', success: false);
      return;
    }
    if (price == null || price <= 0) {
      _showBanner('${t.listingFieldPricePerKg}: ${t.validateGtZero}', success: false);
      return;
    }
    setState(() { _submitting = true; _banner = null; });
    int? createdListingId;
    try {
      final created = await ref.read(adminRepositoryProvider).createListing(
        marketId: _marketId!, categoryId: _categoryId!,
        nameUz: _nameUz.text.trim(), nameRu: _nameRu.text.trim(),
        quantityKg: qty, pricePerKg: price,
        location: _location.text.trim(),
        descriptionUz: _descUz.text.trim(), descriptionRu: _descRu.text.trim(),
      );
      createdListingId = (created['id'] as num).toInt();
      // Soft-fail on individual photo errors — the listing itself already exists, photos can be added via edit.
      final List<String> photoErrors = [];
      for (final p in _pickedPhotos) {
        try {
          await ref.read(adminRepositoryProvider).uploadListingPhoto(createdListingId, p.path);
        } catch (e, st) {
          debugPrint('[AdminNewListingTab] photo upload failed for ${p.path}: $e\n$st');
          photoErrors.add(e.toString());
        }
      }
      ref.invalidate(activeListingsProvider);
      if (!mounted) return;
      // Clear volatile inputs — keep Bozor + Category picks so admin can batch listings under one market.
      for (final c in [_nameUz, _nameRu, _quantity, _price, _location, _descUz, _descRu]) { c.clear(); }
      setState(() => _pickedPhotos.clear());
      _showBanner(photoErrors.isEmpty
          ? t.adminListingCreated
          : '${t.adminListingCreated} (${photoErrors.length} photo upload(s) failed)',
          success: true);
    } catch (e, st) {
      debugPrint('[AdminNewListingTab] submit failed: $e\n$st');
      HapticFeedback.heavyImpact();
      if (mounted) _showBanner(_humanError(e, t), success: false, duration: const Duration(seconds: 4));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

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

    return ListView(controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
      // ---- Animated inline banner — top of form so it's impossible to miss ----
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, anim) => SizeTransition(
          sizeFactor: anim,
          axisAlignment: -1,
          child: FadeTransition(opacity: anim, child: child),
        ),
        child: _banner == null
            ? const SizedBox.shrink(key: ValueKey('empty'))
            : _StatusBanner(
                key: ValueKey(_banner!.message),
                message: _banner!.message,
                success: _banner!.success),
      ),
      if (_banner != null) const SizedBox(height: 16),
      // ---- Photos ----
      Text(t.adminNewListingPhotos, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
      const SizedBox(height: 8),
      _PhotoStrip(photos: _pickedPhotos, onAdd: _pickPhoto,
          onRemove: (i) => setState(() => _pickedPhotos.removeAt(i))),
      const SizedBox(height: 20),
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
            for (final m in list.where((m) => m.isActive)) DropdownMenuItem(value: m.id,
              child: Text('${m.nameUz} · ${m.region}', overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => setState(() => _marketId = v),
        ),
      ),
      const SizedBox(height: 16),
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
      TextField(controller: _nameUz, decoration: InputDecoration(
          labelText: '${t.listingFieldTitle} (UZ)', border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: _nameRu, decoration: InputDecoration(
          labelText: '${t.listingFieldTitle} (RU)', border: const OutlineInputBorder())),
      const SizedBox(height: 12),
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
      FilledButton(onPressed: _submitting ? null : _submit,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        child: _submitting
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(t.adminNewListingSubmit)),
    ]);
  }
}


/// Inline status banner — green on success (check icon), red on error (! icon). Slides in via
/// AnimatedSwitcher in the parent ListView.
class _StatusBanner extends StatelessWidget {
  final String message;
  final bool success;
  const _StatusBanner({super.key, required this.message, required this.success});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final color = success ? const Color(0xFF2E7D32) : Theme.of(context).colorScheme.error;
    final icon = success ? Icons.check_circle_rounded : Icons.error_rounded;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 8, offset: const Offset(0, 2))]),
      child: Row(children: [
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Text(message, style: tt.bodyLarge?.copyWith(
            color: Colors.white, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}


/// Horizontal strip of staged photos + "add" tile.
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
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        if (i == photos.length) {
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
