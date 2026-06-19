import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/providers.dart';
import '../../l10n/app_localizations.dart';


/// Minimal "Add new product" sheet for the Supplier catalog tab.
///
/// Asks for the four fields a supplier must set (name, qty, price, animal form) + picks the first
/// market the supplier owns + the first category by default. v1 — full edit form deferred; for
/// power-user catalog management the supplier opens Django admin or the buyer-app admin section.
///
/// Returns the created listing's id on success so the caller can refresh the list.
Future<int?> showNewListingSheet(BuildContext context) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _NewListingSheet(),
  );
}


class _NewListingSheet extends ConsumerStatefulWidget {
  const _NewListingSheet();
  @override
  ConsumerState<_NewListingSheet> createState() => _NewListingSheetState();
}


class _NewListingSheetState extends ConsumerState<_NewListingSheet> {
  final _name = TextEditingController();
  final _qty = TextEditingController(text: '100');
  final _price = TextEditingController(text: '50000');
  String _form = 'RAW_CUT';                                  // LIVE | RAW_CUT | BOTH

  bool _submitting = false;
  String? _error;

  // Markets + categories — fetched on open so the sheet knows what to POST. We use the first one
  // available; v2 will let the supplier pick from a dropdown.
  int? _marketId;
  int? _categoryId;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _name.dispose(); _qty.dispose(); _price.dispose();
    super.dispose();
  }

  /// Load market + category ids in parallel so the form is ready to post.
  Future<void> _bootstrap() async {
    try {
      final api = ref.read(apiClientProvider);
      final results = await Future.wait([
        api.dio.get('/markets/'),
        api.dio.get('/categories/'),
      ]);
      final markets = _asList(results[0].data);
      final cats = _asList(results[1].data);
      setState(() {
        _marketId = markets.isNotEmpty ? (markets.first['id'] as num).toInt() : null;
        _categoryId = cats.isNotEmpty ? (cats.first['id'] as num).toInt() : null;
        _ready = true;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _ready = true; });
    }
  }

  List<Map<String, dynamic>> _asList(dynamic raw) {
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    if (raw is Map && raw['results'] is List) return (raw['results'] as List).cast<Map<String, dynamic>>();
    return const [];
  }

  bool get _valid {
    if (_submitting || !_ready) return false;
    if (_name.text.trim().length < 2) return false;
    if (double.tryParse(_qty.text) == null) return false;
    if (double.tryParse(_price.text) == null) return false;
    if (_marketId == null || _categoryId == null) return false;
    return true;
  }

  Future<void> _submit() async {
    setState(() { _submitting = true; _error = null; });
    HapticFeedback.selectionClick();
    try {
      final api = ref.read(apiClientProvider);
      final today = DateTime.now();
      final r = await api.dio.post('/listings/', data: {
        'market_id': _marketId,
        'category_id': _categoryId,
        'name_uz': _name.text.trim(),
        'name_ru': _name.text.trim(),
        'quantity_kg': _qty.text.trim(),
        'price_per_kg': _price.text.trim(),
        'location': 'Tashkent',
        'available_from': '${today.year}-${today.month.toString().padLeft(2, "0")}-${today.day.toString().padLeft(2, "0")}',
        'status': 'ACTIVE',
        'animal_form': _form,
      });
      if (!mounted) return;
      if (r.statusCode == 201) {
        final id = (r.data is Map ? r.data['id'] : null) as int?;
        Navigator.pop(context, id);
      } else {
        setState(() {
          _submitting = false;
          _error = _detailFromResponse(r.data) ?? 'HTTP ${r.statusCode}';
        });
      }
    } on DioException catch (e) {
      setState(() {
        _submitting = false;
        _error = _detailFromResponse(e.response?.data) ?? e.message ?? 'Network error';
      });
    } catch (e) {
      setState(() { _submitting = false; _error = e.toString(); });
    }
  }

  String? _detailFromResponse(dynamic data) {
    if (data is Map) {
      if (data['detail'] is String) return data['detail'] as String;
      // DRF field errors look like {field: [msg, ...]}. Join into one readable string.
      final parts = <String>[];
      data.forEach((k, v) {
        if (v is List && v.isNotEmpty) parts.add('$k: ${v.first}');
      });
      if (parts.isNotEmpty) return parts.join('\n');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        child: SafeArea(top: false, child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: Container(width: 40, height: 4,
                margin: const EdgeInsets.only(top: 6, bottom: 16),
                decoration: BoxDecoration(color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2)))),
            Text(t.catalogAddNew,
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            TextField(controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nomi')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: _qty,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Miqdor (kg)'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: "Narx so'm/kg"))),
            ]),
            const SizedBox(height: 14),
            Text("Mahsulot shakli",
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              _FormChip(label: 'Tayyor go\'sht', code: 'RAW_CUT',
                          selected: _form == 'RAW_CUT',
                          onTap: () => setState(() => _form = 'RAW_CUT')),
              _FormChip(label: 'Tirik', code: 'LIVE',
                          selected: _form == 'LIVE',
                          onTap: () => setState(() => _form = 'LIVE')),
              _FormChip(label: 'Ikkalasi', code: 'BOTH',
                          selected: _form == 'BOTH',
                          onTap: () => setState(() => _form = 'BOTH')),
            ]),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: TextStyle(color: cs.error))),
            const SizedBox(height: 20),
            FilledButton(onPressed: _valid ? _submit : null,
              child: _submitting
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(
                      strokeWidth: 2.4, color: Colors.white))
                  : Text(t.save)),
          ]))),
      ),
    );
  }
}


class _FormChip extends StatelessWidget {
  final String label;
  final String code;
  final bool selected;
  final VoidCallback onTap;
  const _FormChip({required this.label, required this.code,
                     required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(onTap: onTap,
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? cs.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? cs.primary : cs.outlineVariant)),
        child: Text(label, style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? cs.onPrimary : cs.onSurface))));
  }
}
