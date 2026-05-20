// Listing creation form — verified suppliers only. v2 adds: photo picker (camera + gallery), halal toggle,
// cold-chain selector, freshness date, service-area CSV.
//
// Submit flow:
//   1. POST /listings/ → creates the listing record
//   2. For each picked photo: POST /listings/{id}/photos/ (multipart) — uploads in sequence
//   3. Invalidate cached providers + pop back
// If step 2 fails partway through, the listing still exists with whatever photos uploaded successfully —
// the supplier can re-edit later. Better than blocking everything on a single upload failure.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/l10n/enum_labels.dart';
import '../../../shared/models/listing.dart';
import '../providers/listings_providers.dart';


class ListingCreateScreen extends ConsumerStatefulWidget {
  const ListingCreateScreen({super.key});
  @override
  ConsumerState<ListingCreateScreen> createState() => _ListingCreateScreenState();
}


class _ListingCreateScreenState extends ConsumerState<ListingCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _qty = TextEditingController();
  final _price = TextEditingController();
  final _location = TextEditingController();
  final _desc = TextEditingController();
  final _serviceArea = TextEditingController();
  DateTime? _availableFrom;
  DateTime? _freshnessDate;
  MeatType _meatType = MeatType.beef;
  ColdChain _coldChain = ColdChain.fresh;
  bool _halal = false;
  final List<XFile> _photos = [];                  // queued photos to upload after the listing is created
  bool _submitting = false;
  String? _error;
  final _picker = ImagePicker();

  @override
  void dispose() {
    for (final c in [_title, _qty, _price, _location, _desc, _serviceArea]) { c.dispose(); }
    super.dispose();
  }

  /// Show a sheet with Camera / Gallery options so the user can pick the source. Multi-pick from gallery in one shot.
  Future<void> _addPhoto() async {
    final t = AppLocalizations.of(context);
    final source = await showModalBottomSheet<ImageSource>(context: context, builder: (sctx) =>
      SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Camera'),
          onTap: () => Navigator.pop(sctx, ImageSource.camera)),
        ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Gallery'),
          onTap: () => Navigator.pop(sctx, ImageSource.gallery)),
        const SizedBox(height: 8),
      ])));
    if (source == null) return;
    try {
      // Camera = single shot. Gallery = multi-select. Both produce XFile(s) that we keep until submit.
      if (source == ImageSource.camera) {
        final shot = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 1600);
        if (shot != null) setState(() => _photos.add(shot));
      } else {
        final picks = await _picker.pickMultiImage(imageQuality: 85, maxWidth: 1600);
        if (picks.isNotEmpty) setState(() => _photos.addAll(picks));
      }
    } catch (e) {
      if (mounted) setState(() => _error = t.failedPrefix(e.toString()));
    }
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate() || _availableFrom == null) {
      if (_availableFrom == null) setState(() => _error = t.listingPickAvailableFrom);
      return;
    }
    if (_photos.isEmpty) { setState(() => _error = t.photoRequired); return; }
    setState(() { _submitting = true; _error = null; });
    try {
      // 1. Create the listing first — gives us an id to attach photos to
      final repo = ref.read(listingsRepositoryProvider);
      final created = await repo.create(
        title: _title.text.trim(), meatType: _meatType,
        quantityKg: double.parse(_qty.text), pricePerKg: double.parse(_price.text),
        location: _location.text.trim(),
        availableFrom: _availableFrom!.toIso8601String().split('T').first,
        description: _desc.text.trim(),
        halalCertified: _halal,
        freshnessDate: _freshnessDate?.toIso8601String().split('T').first,
        coldChain: _coldChain,
        serviceAreaCsv: _serviceArea.text.trim());
      // 2. Upload photos sequentially. If one fails we keep going so a flaky single upload doesn't abort everything.
      for (final p in _photos) {
        try { await repo.uploadPhoto(created.id, p.path); }
        catch (_) { /* ignored — listing already exists; supplier can re-add later */ }
      }
      ref..invalidate(listingsBrowseProvider)..invalidate(myListingsProvider);
      if (mounted) context.pop();
    } catch (e) { setState(() { _error = e.toString(); }); }
    finally { if (mounted) setState(() => _submitting = false); }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(t.newListing)),
      body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // ---------- Photos section (v2) ----------
          _SectionLabel(t.addPhoto),
          _PhotoStrip(photos: _photos, onAdd: _addPhoto,
            onRemove: (i) => setState(() => _photos.removeAt(i))),
          const SizedBox(height: 20),

          TextFormField(controller: _title,
            decoration: InputDecoration(labelText: t.listingFieldTitle),
            validator: (v) => (v == null || v.trim().length < 3) ? t.listingMinTitleChars : null),
          const SizedBox(height: 18),

          _SectionLabel(t.listingFieldMeatType),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final mt in MeatType.values) ChoiceChip(
              label: Text(mt.label(context)),
              selected: _meatType == mt,
              onSelected: (_) => setState(() => _meatType = mt)),
          ]),
          const SizedBox(height: 18),

          Row(children: [
            Expanded(child: TextFormField(controller: _qty, keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: t.listingFieldQuantity),
              validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? t.validateGtZero : null)),
            const SizedBox(width: 12),
            Expanded(child: TextFormField(controller: _price, keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: t.listingFieldPricePerKg),
              validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? t.validateGtZero : null)),
          ]),
          const SizedBox(height: 12),
          TextFormField(controller: _location,
            decoration: InputDecoration(labelText: t.listingFieldLocation),
            validator: (v) => (v == null || v.isEmpty) ? t.validateRequired : null),
          const SizedBox(height: 12),

          // Available-from date — required
          _DateTile(label: t.listingFieldAvailableFrom, value: _availableFrom,
            onPick: (d) => setState(() => _availableFrom = d), firstDate: DateTime.now()),
          const SizedBox(height: 12),
          // Freshness (slaughter) date — optional, can be in the past
          _DateTile(label: t.freshnessDate, value: _freshnessDate,
            onPick: (d) => setState(() => _freshnessDate = d),
            firstDate: DateTime.now().subtract(const Duration(days: 30))),
          const SizedBox(height: 18),

          // Cold chain — single-select chip row
          _SectionLabel(t.listingFieldStatus),  // re-using "Holati" label; clearer key would be coldChainLabel later
          Wrap(spacing: 8, children: [
            ChoiceChip(label: Text(t.coldChainFresh), selected: _coldChain == ColdChain.fresh,
              onSelected: (_) => setState(() => _coldChain = ColdChain.fresh)),
            ChoiceChip(label: Text(t.coldChainChilled), selected: _coldChain == ColdChain.chilled,
              onSelected: (_) => setState(() => _coldChain = ColdChain.chilled)),
            ChoiceChip(label: Text(t.coldChainFrozen), selected: _coldChain == ColdChain.frozen,
              onSelected: (_) => setState(() => _coldChain = ColdChain.frozen)),
          ]),
          const SizedBox(height: 18),

          // Halal toggle — switch tile is a clear yes/no affordance
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _halal, onChanged: (v) => setState(() => _halal = v),
            title: Text(t.halal, style: tt.bodyLarge),
            secondary: const Icon(Icons.verified_outlined),
          ),
          const SizedBox(height: 12),

          TextFormField(controller: _serviceArea,
            decoration: InputDecoration(labelText: t.serviceArea,
              hintText: t.serviceAreaHint)),
          const SizedBox(height: 12),

          TextFormField(controller: _desc, maxLines: 3,
            decoration: InputDecoration(labelText: t.listingFieldDescriptionOptional)),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: tt.bodyMedium?.copyWith(color: cs.error))),
          const SizedBox(height: 24),
          FilledButton(onPressed: _submitting ? null : _submit,
              child: _submitting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                 : Text(t.createListingButton)),
        ])))),
    );
  }
}


/// Small ALL-CAPS section label — matches the iOS Settings group-header look used elsewhere.
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(4, 0, 0, 10),
    child: Text(text.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 0.6)));
}


/// Horizontal strip of picked-photo thumbnails + an "Add" tile at the end.
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
      itemCount: photos.length + 1,                 // +1 for the trailing "Add" tile
      separatorBuilder: (_, _) => const SizedBox(width: 10),
      itemBuilder: (_, i) {
        if (i == photos.length) {
          // "+" tile — same dimensions as a thumbnail so the row stays visually tidy
          return GestureDetector(onTap: onAdd,
            child: Container(width: 96, height: 96,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant, width: 1)),
              child: Icon(Icons.add_a_photo_outlined, size: 28, color: cs.onSurfaceVariant)));
        }
        return SizedBox(width: 96, child: Stack(children: [
          // Thumbnail
          Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(12),
            child: Image.file(File(photos[i].path), fit: BoxFit.cover))),
          // Remove (X) button overlay
          Positioned(top: 4, right: 4, child: GestureDetector(
            onTap: () => onRemove(i),
            child: Container(width: 22, height: 22,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.6)),
              child: const Icon(Icons.close, size: 14, color: Colors.white)))),
        ]));
      },
    ));
  }
}


/// Tappable date-picker tile — same visual style as the InputDecoration filled fields.
class _DateTile extends StatelessWidget {
  final String label;
  final DateTime? value;
  final void Function(DateTime) onPick;
  final DateTime firstDate;
  const _DateTile({required this.label, required this.value, required this.onPick, required this.firstDate});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return InkWell(borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final picked = await showDatePicker(context: context, firstDate: firstDate,
            lastDate: DateTime.now().add(const Duration(days: 365)),
            initialDate: value ?? DateTime.now());
        if (picked != null) onPick(picked);
      },
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(Icons.calendar_today_outlined, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(child: Text(value == null ? label : value!.toIso8601String().split('T').first,
            style: value == null ? tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant) : tt.bodyLarge)),
          Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
        ])));
  }
}
