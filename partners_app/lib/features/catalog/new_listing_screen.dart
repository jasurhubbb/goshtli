import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/providers.dart';
import '../../l10n/app_localizations.dart';


/// Full-page "Yangi tovar qo'shish".
///
/// Bootstrap fetches three things in parallel:
///   • /markets/me/   — supplier's own Market (auto-created server-side on first call). Falls back
///     to /markets/ → first row when the prod backend doesn't have the endpoint yet (Railway deploy
///     lag). The fallback fires a warning so the supplier knows their listing might land under
///     someone else's shopfront until the backend redeploys.
///   • /categories/   — meat categories (Mol/Qo'y/Tovuq/Echki/Ot/Qiyma/Jigar/Boshqa).
///   • /suppliers/me/ — animals_supported list so the chip row filters to what THIS supplier sells
///     (their wizard pick). Extras (Qiyma/Jigar/Boshqa) always show as "add-ons".
///
/// All four picker fields (qty, price, go'sht turi, mahsulot shakli) start empty/unselected — no
/// silent defaults that the user would otherwise have to clear before Saqlash unlocks.
class NewListingScreen extends ConsumerStatefulWidget {
  const NewListingScreen({super.key});
  @override
  ConsumerState<NewListingScreen> createState() => _NewListingScreenState();
}


class _NewListingScreenState extends ConsumerState<NewListingScreen> {
  final _name = TextEditingController();
  final _qty = TextEditingController();
  final _price = TextEditingController();
  String? _form;                                  // null until user taps a chip — no RAW_CUT default
  File? _photo;

  bool _submitting = false;
  bool _ready = false;
  String? _error;
  String? _warning;                               // soft "your listing will land under X" notice

  int? _marketId;
  int? _categoryId;
  List<Map<String, dynamic>> _categories = const [];
  // Subset of categories matching the supplier's `animals_supported` + the always-on extras (Qiyma,
  // Jigar, Boshqa). Computed once in _bootstrap so the build method stays cheap.
  List<Map<String, dynamic>> _visibleCategories = const [];

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

  /// Maps a category's `name_uz` to the wizard animal codes so we can filter by what the supplier
  /// said they sell during onboarding. Heuristic — keyed by Uzbek name substring because the DB has
  /// no formal animal-code column on MeatCategory. If a new category gets added that doesn't match
  /// any of these, it's treated as an "extra" and shown to everyone.
  static const _animalKeywords = {
    'MOL': 'mol',
    'QOY': "qo'y",
    'ECHKI': 'echki',
    'OT': 'ot ',                                  // trailing space avoids matching "boshqa"/etc.
    'TOVUQ': 'tovuq',
  };
  // Categories that always appear regardless of animal selection — generic SKUs every supplier may sell.
  static const _alwaysVisibleNames = {'qiyma', 'jigar', 'boshqa'};

  Future<void> _bootstrap() async {
    final api = ref.read(apiClientProvider);
    String? warning;
    int? marketId;
    List<Map<String, dynamic>> cats = const [];
    List<String> animals = const [];

    // /markets/me/ may 404 on production until the v3.8.2 backend deploys to Railway. Catch that
    // case and fall back to /markets/ → first row so the form remains usable + flag a warning.
    try {
      final r = await api.dio.get('/markets/me/');
      if (r.data is Map && r.data['id'] is num) {
        marketId = (r.data['id'] as num).toInt();
      } else {
        throw Exception('Unexpected /markets/me/ shape');
      }
    } catch (_) {
      try {
        final r = await api.dio.get('/markets/');
        final list = _asList(r.data);
        if (list.isNotEmpty) {
          marketId = (list.first['id'] as num).toInt();
          warning = 'Server eski versiyada — bu listing umumiy bozorga biriktiriladi. '
                    'Backend yangilanganidan keyin yangi listinglar avtomatik o\'z bozoringizga tushadi.';
        }
      } catch (_) {}
    }

    try {
      final r = await api.dio.get('/categories/');
      cats = _asList(r.data);
    } catch (_) {}

    // animals_supported drives the chip filter. If the fetch fails or the list is empty, fall back
    // to showing ALL categories so the supplier isn't locked out.
    try {
      final r = await api.dio.get('/suppliers/me/');
      if (r.data is Map && r.data['animals_supported'] is List) {
        animals = (r.data['animals_supported'] as List).map((e) => e.toString().toUpperCase()).toList();
      }
    } catch (_) {}

    final visible = animals.isEmpty
        ? cats                                    // unfiltered fallback — better than empty list
        : cats.where((c) {
            final name = ((c['name_uz'] as String?) ?? '').toLowerCase();
            if (_alwaysVisibleNames.any(name.contains)) return true;
            for (final a in animals) {
              final kw = _animalKeywords[a];
              if (kw != null && name.contains(kw)) return true;
            }
            return false;
          }).toList();

    if (!mounted) return;
    setState(() {
      _marketId = marketId;
      _categories = cats;
      _visibleCategories = visible;
      _warning = warning;
      _ready = true;
    });
  }

  List<Map<String, dynamic>> _asList(dynamic raw) {
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    if (raw is Map && raw['results'] is List) return (raw['results'] as List).cast<Map<String, dynamic>>();
    return const [];
  }

  /// Image picker — gallery only for now. 80% quality keeps thumbs readable without blowing up file
  /// size; camera source needs platform-perm boilerplate we can add in v2.
  Future<void> _pickPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked != null) setState(() => _photo = File(picked.path));
    } catch (_) {}
  }

  bool get _valid {
    if (_submitting || !_ready) return false;
    if (_name.text.trim().length < 2) return false;
    if (double.tryParse(_qty.text) == null) return false;
    if (double.tryParse(_price.text) == null) return false;
    if (_marketId == null || _categoryId == null || _form == null) return false;
    return true;
  }

  Future<void> _submit() async {
    setState(() { _submitting = true; _error = null; });
    HapticFeedback.selectionClick();
    try {
      final api = ref.read(apiClientProvider);
      final today = DateTime.now();
      final r = await api.dio.post('/listings/', data: {
        'market_id': _marketId, 'category_id': _categoryId,
        'name_uz': _name.text.trim(), 'name_ru': _name.text.trim(),
        'quantity_kg': _qty.text.trim(), 'price_per_kg': _price.text.trim(),
        'location': 'Tashkent',
        'available_from': '${today.year}-${today.month.toString().padLeft(2, "0")}-${today.day.toString().padLeft(2, "0")}',
        'status': 'ACTIVE', 'animal_form': _form,
      });
      if (r.statusCode != 201) {
        setState(() {
          _submitting = false;
          _error = _detailFromResponse(r.data) ?? 'HTTP ${r.statusCode}';
        });
        return;
      }
      final id = (r.data is Map ? r.data['id'] : null) as int?;
      // Photo upload is fire-and-forget — if it fails the listing still exists, supplier can attach
      // a photo later via the catalog edit screen (v2).
      if (id != null && _photo != null) {
        try {
          final form = FormData.fromMap({
            'image': await MultipartFile.fromFile(_photo!.path,
                filename: _photo!.path.split('/').last),
          });
          await api.dio.post('/listings/$id/photos/', data: form);
        } catch (_) {}
      }
      if (mounted) context.pop(id);
    } on DioException catch (e) {
      setState(() {
        _submitting = false;
        _error = _detailFromResponse(e.response?.data) ?? e.message ?? 'Network error';
      });
    } catch (e) {
      setState(() { _submitting = false; _error = e.toString(); });
    }
  }

  /// Flattens DRF error shapes (`{detail:"..."}` for permission, `{field:[msg]}` for validation) to
  /// one inline line — better than swallowing the actual reason behind a generic "saqlash failed".
  String? _detailFromResponse(dynamic data) {
    if (data is Map) {
      if (data['detail'] is String) return data['detail'] as String;
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
    // If category filter wiped everything (e.g. supplier picked an animal that has no matching
    // category yet), fall back to the full list so the form remains usable.
    final cats = _visibleCategories.isEmpty ? _categories : _visibleCategories;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => context.pop()),
        title: Text(t.catalogAddNew)),
      body: SafeArea(child: !_ready
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            // onChanged on the TextFields rebuilds button state — without this, _valid runs only on
            // chip taps and Saqlash never enables after typing the last field.
            children: [
              GestureDetector(onTap: _pickPhoto,
                child: Container(height: 180,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: cs.outlineVariant)),
                  child: _photo == null
                      ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.add_a_photo_outlined, size: 40, color: cs.onSurfaceVariant),
                          const SizedBox(height: 8),
                          Text('Tasvir qo\'shish (ixtiyoriy)',
                              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                        ])
                      : ClipRRect(borderRadius: BorderRadius.circular(18),
                          child: Image.file(_photo!, fit: BoxFit.cover,
                              width: double.infinity, height: double.infinity)))),
              const SizedBox(height: 18),
              TextField(controller: _name,
                onChanged: (_) => setState(() {}),
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nomi *', hintText: 'Barra go\'shti')),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: TextField(controller: _qty,
                    onChanged: (_) => setState(() {}),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Miqdor (kg) *'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _price,
                    onChanged: (_) => setState(() {}),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: "Narx so'm/kg *"))),
              ]),
              const SizedBox(height: 18),
              Text("Go'sht turi *",
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text("Profil tabidan yangi turlarni qo'shishingiz mumkin",
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: cats.map((c) {
                final id = (c['id'] as num).toInt();
                final label = (c['name_uz'] as String?) ?? (c['name_ru'] as String?) ?? '—';
                return _FormChip(label: label, selected: _categoryId == id,
                    onTap: () => setState(() => _categoryId = id));
              }).toList()),
              const SizedBox(height: 18),
              Text("Mahsulot shakli *",
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _FormChip(label: 'Tayyor go\'sht', selected: _form == 'RAW_CUT',
                            onTap: () => setState(() => _form = 'RAW_CUT')),
                _FormChip(label: 'Tirik', selected: _form == 'LIVE',
                            onTap: () => setState(() => _form = 'LIVE')),
                _FormChip(label: 'Ikkalasi', selected: _form == 'BOTH',
                            onTap: () => setState(() => _form = 'BOTH')),
              ]),
              if (_warning != null) Padding(padding: const EdgeInsets.only(top: 16),
                  child: Container(padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFFFF4E5),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text(_warning!,
                        style: tt.bodySmall?.copyWith(color: const Color(0xFF8A4F00))))),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 16),
                  child: Text(_error!, style: TextStyle(color: cs.error))),
              const SizedBox(height: 28),
              FilledButton(onPressed: _valid ? _submit : null,
                child: _submitting
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: Colors.white))
                    : Text(t.save)),
            ])),
    );
  }
}


class _FormChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FormChip({required this.label, required this.selected, required this.onTap});

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
