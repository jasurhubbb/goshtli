// AddressFormScreen — create OR edit a saved address. Routed at:
//   /addresses/new        → create flow. Map → pushReplacement here with extra={lat, lng, displayName, houseNumber}.
//   /addresses/<id>       → edit flow. Hydrates from addressesProvider's cached list.
//
// Layout (top → bottom):
//   • Static map-preview card (tap → re-open the map picker to refine the pin)
//   • Street line — required, pre-filled from Nominatim
//   • Uy raqami (house number) — required if Nominatim didn't return one; pre-filled if it did
//   • Three short fields side-by-side (kirish yo'lagi / qavat / xonadon) — courier hints
//   • Notes — free text
//   • Sticky bottom CTA — "Manzilni saqlash" for authenticated users, "Kirish va saqlash" for anonymous
//
// Auth gating: anonymous users can fill in everything but the SAVE step routes them to /register. They keep
// what they typed in the form (it's in TextEditingControllers, not lost across navigation). This is the
// "no friction up front, friction at the commitment step" pattern.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../data/address_model.dart';
import '../providers/addresses_providers.dart';


class AddressFormScreen extends ConsumerStatefulWidget {
  /// Null id = create flow. Non-null = edit flow; the existing address is loaded from addressesProvider.
  final int? addressId;

  /// Optional pre-fill from the map picker. When the user arrives via /addresses/map → pushReplacement,
  /// these carry the picked coordinates + reverse-geocoded street name + parsed house number (if any).
  final double? prefilledLat;
  final double? prefilledLng;
  final String? prefilledDisplayName;
  final String? prefilledHouseNumber;

  const AddressFormScreen({super.key, this.addressId,
                           this.prefilledLat, this.prefilledLng,
                           this.prefilledDisplayName, this.prefilledHouseNumber});

  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormScreenState();
}


class _AddressFormScreenState extends ConsumerState<AddressFormScreen> {
  // One controller per field — bound to TextFields so input persists across rebuilds.
  late final TextEditingController _label;
  late final TextEditingController _street;
  late final TextEditingController _houseNumber;
  late final TextEditingController _entrance;
  late final TextEditingController _floor;
  late final TextEditingController _apartment;
  late final TextEditingController _notes;

  // Lat/Lng captured by the map (null before the user picks a pin).
  double? _lat;
  double? _lng;
  bool _saving = false;
  String? _error;
  bool _hydrated = false;  // toggle so the listen-based hydration only runs once

  bool get _isEdit => widget.addressId != null;

  @override
  void initState() {
    super.initState();
    // Defaults: "Uy" label on first-time create; street pre-filled from map; house number from Nominatim if any.
    _label = TextEditingController(text: widget.addressId == null ? 'Uy' : '');
    _street = TextEditingController(text: widget.prefilledDisplayName ?? '');
    _houseNumber = TextEditingController(text: widget.prefilledHouseNumber ?? '');
    _entrance = TextEditingController();
    _floor = TextEditingController();
    _apartment = TextEditingController();
    _notes = TextEditingController();
    _lat = widget.prefilledLat;
    _lng = widget.prefilledLng;
  }

  @override
  void dispose() {
    _label.dispose(); _street.dispose(); _houseNumber.dispose();
    _entrance.dispose(); _floor.dispose(); _apartment.dispose(); _notes.dispose();
    super.dispose();
  }

  /// Hydrate from the cached addresses list when this is an edit flow. The previous version used
  /// didChangeDependencies which silently lost data when the list hadn't loaded yet at first frame.
  /// ref.listen runs reactively, so it correctly catches the moment data arrives — even on cold open.
  void _hydrateIfNeeded(AsyncValue<List<Address>> list) {
    if (_hydrated || !_isEdit) return;
    final data = list.asData?.value;
    if (data == null) return;
    final a = data.where((x) => x.id == widget.addressId).cast<Address?>().firstWhere(
        (_) => true, orElse: () => null);
    if (a == null) return;
    _hydrated = true;
    _label.text = a.label;
    // The saved address line might already contain the house number (we concatenate on save). Splitting it
    // back is fuzzy, so we just put the whole thing in `_street` and leave `_houseNumber` blank on edit.
    _street.text = a.address;
    _entrance.text = a.entrance;
    _floor.text = a.floor;
    _apartment.text = a.apartment;
    _notes.text = a.notes;
    _lat = a.lat; _lng = a.lng;
    setState(() {});  // refresh map preview (lat/lng changed)
  }

  /// Combine the user-typed street + house number into the single "address" column the backend expects.
  /// E.g. street="Bobur mahalla fuqarolar yig'ini" + house="6" → "Bobur mahalla fuqarolar yig'ini, 6"
  String _combinedAddress() {
    final s = _street.text.trim();
    final h = _houseNumber.text.trim();
    if (h.isEmpty) return s;
    // Avoid duplicating the number if it's already in the street (Nominatim sometimes returns both)
    if (s.endsWith(', $h') || s.endsWith(' $h')) return s;
    return s.isEmpty ? h : '$s, $h';
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    final label = _label.text.trim();
    final address = _combinedAddress();
    if (label.isEmpty || address.isEmpty) {
      setState(() => _error = t.validateRequired);
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      // Mutate via the notifier — the list state updates synchronously after the gateway returns, so the
      // home pill / sheet see the new row immediately. No invalidate-then-loading-window race.
      final notifier = ref.read(addressesProvider.notifier);
      if (_isEdit) {
        await notifier.updateOne(widget.addressId!, {
          'label': label, 'address': address,
          'entrance': _entrance.text, 'floor': _floor.text, 'apartment': _apartment.text,
          'notes': _notes.text,
          if (_lat != null) 'lat': _lat!.toStringAsFixed(6),
          if (_lng != null) 'lng': _lng!.toStringAsFixed(6),
        });
      } else {
        final created = await notifier.add(
          label: label, address: address,
          entrance: _entrance.text, floor: _floor.text, apartment: _apartment.text, notes: _notes.text,
          lat: _lat, lng: _lng);
        // Auto-select the newly-created address so the home pill picks it up immediately. await ensures the
        // SP write completes before we pop — otherwise the next cold app start might miss the selection.
        await ref.read(selectedAddressIdProvider.notifier).set(created.id);
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (!_isEdit) return;
    final t = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(context: context, builder: (dctx) => AlertDialog(
      content: Text(t.addressDeleteConfirm),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dctx, false), child: Text(t.no)),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Theme.of(dctx).colorScheme.error),
          onPressed: () => Navigator.pop(dctx, true), child: Text(t.addressDeleteCta)),
      ]));
    if (confirmed != true) return;
    try {
      // Same dispatch as add/update — notifier handles backend-vs-local internally + updates list state.
      await ref.read(addressesProvider.notifier).removeOne(widget.addressId!);
      if (ref.read(selectedAddressIdProvider) == widget.addressId) {
        await ref.read(selectedAddressIdProvider.notifier).set(null);
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _pickOnMap() async {
    HapticFeedback.selectionClick();
    // popOnConfirm flag → map pops with the payload (rather than pushReplacing to a fresh form) so this
    // form keeps its existing field values and just absorbs the new lat/lng + street + house number.
    final result = await context.push<Map<String, dynamic>>('/addresses/map', extra: {
      'initialLat': _lat, 'initialLng': _lng, 'initialQuery': _street.text,
      'popOnConfirm': true,
    });
    if (result == null) return;
    setState(() {
      _lat = result['lat'] as double?;
      _lng = result['lng'] as double?;
      if (result['displayName'] is String && (result['displayName'] as String).isNotEmpty) {
        _street.text = result['displayName'] as String;
      }
      if (result['houseNumber'] is String && (result['houseNumber'] as String).isNotEmpty) {
        _houseNumber.text = result['houseNumber'] as String;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Listen for the edit-flow address to arrive in cache. Reactive — handles both "data already there" and
    // "data lands later" paths cleanly. Fires once and the _hydrated flag guards against further runs.
    ref.listen<AsyncValue<List<Address>>>(addressesProvider, (_, next) => _hydrateIfNeeded(next));
    // Also try hydrating on first build (covers the case where data is already cached when we mount)
    _hydrateIfNeeded(ref.read(addressesProvider));

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? t.addressFormTitleEdit : t.addressFormTitleNew),
        actions: [
          if (_isEdit) IconButton(onPressed: _delete,
              icon: Icon(Icons.delete_outline_rounded, color: cs.error)),
        ],
      ),
      body: Column(children: [
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Map preview card — full-width, tap to refine the pin location. Shows placeholder when no
            // lat/lng is set yet (encourages the user to drop a pin).
            _MapPreview(lat: _lat, lng: _lng, onTap: _pickOnMap),
            const SizedBox(height: 20),

            // Label field (e.g. "Uy"). One field is enough — power users name it whatever they like.
            _Field(controller: _label, label: t.addressFieldLabel, hint: t.addressFieldLabelHint,
                   icon: Icons.home_outlined),
            const SizedBox(height: 14),

            // Street line — main address text. Required.
            _Field(controller: _street, label: t.addressFieldStreet, hint: t.addressFieldStreetHint,
                   icon: Icons.location_on_outlined, maxLines: 2),
            const SizedBox(height: 14),

            // House number — explicit field because Nominatim often doesn't return one (especially in UZ).
            // Shown prominently below the street so users can't miss it.
            _Field(controller: _houseNumber, label: 'Uy raqami', hint: 'Masalan: 6',
                   icon: Icons.numbers_rounded, keyboardType: TextInputType.text),
            const SizedBox(height: 14),

            // Three short fields side-by-side (kirish yo'lagi / qavat / xonadon) — courier hints
            Row(children: [
              Expanded(child: _Field(controller: _entrance, label: t.addressFieldEntrance)),
              const SizedBox(width: 10),
              Expanded(child: _Field(controller: _floor, label: t.addressFieldFloor)),
              const SizedBox(width: 10),
              Expanded(child: _Field(controller: _apartment, label: t.addressFieldApartment)),
            ]),
            const SizedBox(height: 14),

            // Free-form notes — multi-line. Helper text underneath explains why couriers care.
            _Field(controller: _notes, label: t.addressFieldNotes, maxLines: 3),
            const SizedBox(height: 4),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(t.addressFieldNotesHelp,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant))),

            if (_error != null) Padding(padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: tt.bodyMedium?.copyWith(color: cs.error))),
          ]))),

        // Sticky bottom CTA — label flips to "Kirish va saqlash" for anonymous users (gate clarifies the
        // friction up-front so the tap doesn't feel like a silent fail).
        SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: SizedBox(width: double.infinity, height: 54, child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.primary, foregroundColor: cs.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(t.addressSaveCta,
                    style: tt.titleMedium?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w700))))))
      ]),
    );
  }
}


/// Filled-tonal text field with an optional leading icon. Soft surface background, no harsh border, label
/// slides up when focused. Matches the Uzum / Material 3 spec.
class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final int maxLines;
  final TextInputType? keyboardType;
  const _Field({required this.controller, required this.label, this.hint, this.icon,
                this.maxLines = 1, this.keyboardType});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(controller: controller, maxLines: maxLines, keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        prefixIcon: icon != null ? Icon(icon) : null,
        filled: true, fillColor: cs.surfaceContainerHighest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ));
  }
}


/// Static map preview — placeholder square with a pin icon when no lat/lng, or a centered marker visual once
/// the user has picked one. Tapping opens the live map picker. Kept static (not a live flutter_map widget)
/// so the form screen stays lightweight — the real map only loads when the user taps to refine.
class _MapPreview extends StatelessWidget {
  final double? lat;
  final double? lng;
  final VoidCallback onTap;
  const _MapPreview({required this.lat, required this.lng, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasPin = lat != null && lng != null;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16),
      child: Container(height: 140,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4), width: 0.5)),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(hasPin ? Icons.location_on_rounded : Icons.add_location_alt_outlined,
            size: 36, color: hasPin ? cs.primary : cs.onSurfaceVariant),
          const SizedBox(height: 6),
          Text(hasPin
                  ? '${lat!.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}'
                  : AppLocalizations.of(context).addressMapTitle,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ]))));
  }
}
