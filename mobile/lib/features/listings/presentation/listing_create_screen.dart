// Listing creation form — verified suppliers only. Cleaner Apple-style spacing + iOS-y date picker tile.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  DateTime? _availableFrom;
  MeatType _meatType = MeatType.beef;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_title, _qty, _price, _location, _desc]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate() || _availableFrom == null) {
      if (_availableFrom == null) setState(() => _error = t.listingPickAvailableFrom);
      return;
    }
    setState(() { _submitting = true; _error = null; });
    try {
      await ref.read(listingsRepositoryProvider).create(
        title: _title.text.trim(), meatType: _meatType,
        quantityKg: double.parse(_qty.text), pricePerKg: double.parse(_price.text),
        location: _location.text.trim(),
        availableFrom: _availableFrom!.toIso8601String().split('T').first,
        description: _desc.text.trim());
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
          TextFormField(controller: _title,
            decoration: InputDecoration(labelText: t.listingFieldTitle),
            validator: (v) => (v == null || v.trim().length < 3) ? t.listingMinTitleChars : null),
          const SizedBox(height: 18),
          // Meat type — wrap of choice chips, slightly larger tap target
          Padding(padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
            child: Text(t.listingFieldMeatType.toUpperCase(),
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant, letterSpacing: 0.6))),
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
          // Date picker — iOS-y filled tile with a calendar icon, opens platform picker
          InkWell(borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(context: context, firstDate: now,
                  lastDate: now.add(const Duration(days: 365)), initialDate: now);
              if (picked != null) setState(() => _availableFrom = picked);
            },
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Icon(Icons.calendar_today_outlined, size: 18, color: cs.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(child: Text(
                  _availableFrom == null ? t.listingFieldAvailableFrom
                                         : _availableFrom!.toIso8601String().split('T').first,
                  style: _availableFrom == null
                      ? tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)
                      : tt.bodyLarge)),
                Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
              ]))),
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
