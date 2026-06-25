import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/providers.dart';
import '../../shared/widgets/image_source_picker.dart';


/// Servisim — qassob-only tab 3. CRUD surface for the v3.9 service-profile fields the buyer-app
/// detail page renders (bio / specialties / certifications / working_hours / price_list / languages
/// / gallery). Replaces the previous Calendar (Jadval) tab for qassobs; the underlying capacity
/// schedule still exists and is reachable via the "Sig'im jadvali" shortcut at the top of this
/// screen.
///
/// Design notes:
///   • One scrolling page, sectioned. Each structured-data section has its own inline editor + a
///     shared bottom Save button that PATCHes /qassobs/me/ with the full edited payload. Less
///     dialog-juggling than a per-section save (avoids the "save one, forget another" pitfall) and
///     less anxiety than a top-level "edit profile" modal.
///   • Gallery is the exception — uploads go through /qassobs/me/photos/ (multipart) so each add/
///     delete is an immediate network call. Reorder isn't surfaced in this v1 — drag-handle UI can
///     come later; the backend reorder endpoint is ready.
///   • All texts inline-localized to UZ — l10n keys for the new strings can land in a follow-up
///     gen-l10n pass; not blocking shipping.
class ServisimScreen extends ConsumerStatefulWidget {
  const ServisimScreen({super.key});
  @override
  ConsumerState<ServisimScreen> createState() => _ServisimScreenState();
}


/// Loads the qassob's profile shape on tab open + caches it. Invalidated by the Save button.
///
/// v3.9.6: handles the "role flipped to QASSOB via admin but no QassobProfile row" case that bit
/// users whose accounts were created before the v3.8.3 role-accepting backend deployed. When
/// `/qassobs/me/` returns 404, we POST a minimal profile (full_name pulled from /auth/me/ via the
/// JWT claim) and re-fetch so Servisim renders an editable empty profile instead of a dead-end
/// "Profil topilmadi" message.
final qassobMeProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final api = ref.read(apiClientProvider);
  try {
    final r = await api.dio.get('/qassobs/me/');
    if (r.statusCode == 200 && r.data is Map) {
      return Map<String, dynamic>.from(r.data as Map);
    }
    // 404 → profile doesn't exist yet. Bootstrap it with safe defaults that match the v3.8 wizard's
    // first-save shape. The POST will 409 if a profile already exists (race) — in which case we
    // just re-GET and return the existing row.
    if (r.statusCode == 404) {
      Map<String, dynamic>? me;
      try {
        final meResp = await api.dio.get('/auth/me/');
        if (meResp.data is Map) me = Map<String, dynamic>.from(meResp.data as Map);
      } catch (_) {}
      final fullName = (me?['full_name'] as String?)?.trim();
      final createPayload = <String, dynamic>{
        'full_name': (fullName != null && fullName.isNotEmpty) ? fullName : 'Qassob',
        'years_experience': 0,
        'region': 'Toshkent',
        'address': '',
        'animals_supported': const <String>[],
        'is_slaughterhouse': false,
        'daily_capacity_head': 10,
      };
      try {
        await api.dio.post('/qassobs/me/', data: createPayload);
      } catch (_) {/* swallow — re-GET below will tell the real story */}
      final r2 = await api.dio.get('/qassobs/me/');
      if (r2.statusCode == 200 && r2.data is Map) {
        return Map<String, dynamic>.from(r2.data as Map);
      }
    }
  } catch (_) {}
  return null;
});


class _ServisimScreenState extends ConsumerState<ServisimScreen> {
  // Editable local copies — seeded from the fetched profile, written back via Save. v3.9.9
  // dropped the price-list + certifications sections per product feedback (qassobs don't have a
  // structured menu to publish; pricing is negotiated per job over chat). Backend fields stay so
  // existing rows keep their data, but the editor no longer surfaces them.
  final _bioCtrl = TextEditingController();
  final Set<String> _languages = {};
  List<String> _specialties = [];
  // Working hours keyed by weekday code (mon..sun). null = closed.
  final Map<String, _HourRange?> _hours = {
    'mon': null, 'tue': null, 'wed': null, 'thu': null, 'fri': null, 'sat': null, 'sun': null,
  };
  bool _hydrated = false;
  bool _saving = false;
  String? _saveError;

  @override
  void dispose() {
    _bioCtrl.dispose();
    super.dispose();
  }

  /// Seeds editable state from the fetched profile shape on first build. Idempotent — guarded by
  /// _hydrated so a rebuild after Save (which re-fetches) doesn't blow away the user's mid-edit
  /// changes — once they save once, _hydrated stays true.
  void _hydrate(Map<String, dynamic> m) {
    if (_hydrated) return;
    _bioCtrl.text = (m['bio'] as String?) ?? '';
    _specialties = ((m['specialties'] as List?) ?? const [])
        .map((e) => e.toString()).toList();
    _languages.clear();
    _languages.addAll(((m['languages'] as List?) ?? const [])
        .map((e) => e.toString().toLowerCase()));
    final wh = (m['working_hours'] as Map?) ?? const {};
    for (final day in _hours.keys.toList()) {
      final raw = wh[day];
      if (raw is List && raw.length == 2 && raw[0] is num && raw[1] is num) {
        _hours[day] = _HourRange((raw[0] as num).toInt(), (raw[1] as num).toInt());
      } else {
        _hours[day] = null;
      }
    }
    _hydrated = true;
  }

  Future<void> _save() async {
    setState(() { _saving = true; _saveError = null; });
    HapticFeedback.selectionClick();
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Reshape local edits into the wire payload that /qassobs/me/ PATCH expects. price_list +
      // certifications intentionally omitted — see field declarations above.
      final payload = <String, dynamic>{
        'bio': _bioCtrl.text.trim(),
        'specialties': _specialties.map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
        'languages': _languages.toList(),
        'working_hours': {
          for (final entry in _hours.entries)
            entry.key: entry.value == null ? null : [entry.value!.open, entry.value!.close],
        },
      };
      final r = await ref.read(apiClientProvider).dio.patch('/qassobs/me/', data: payload);
      final ok = (r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300);
      if (!ok) {
        final detail = (r.data is Map && r.data['detail'] is String)
            ? r.data['detail'] as String : 'HTTP ${r.statusCode}';
        setState(() { _saveError = detail; _saving = false; });
        return;
      }
      messenger.showSnackBar(const SnackBar(content: Text('Saqlandi')));
      ref.invalidate(qassobMeProvider);
      setState(() => _saving = false);
    } on DioException catch (e) {
      final data = e.response?.data;
      final detail = (data is Map && data['detail'] is String)
          ? data['detail'] as String : e.message ?? 'Network error';
      setState(() { _saveError = detail; _saving = false; });
    } catch (e) {
      setState(() { _saveError = e.toString(); _saving = false; });
    }
  }

  // ---- gallery handlers (immediate network calls, no batched save) ----

  Future<void> _pickAndUploadPhoto(int qassobMaybeUnused) async {
    // Capture messenger BEFORE the await so we don't reach into context after an async gap.
    final messenger = ScaffoldMessenger.of(context);
    // showImageSourcePicker presents the camera-or-gallery sheet so qassobs can either snap a fresh
    // workplace photo or pick one from their phone — previously the only option was the gallery,
    // which was a dead-end for qassobs without an existing shot.
    final pickedPath = await showImageSourcePicker(context, imageQuality: 82);
    if (pickedPath == null) return;
    setState(() => _saving = true);
    try {
      final form = FormData.fromMap({
        'image': await MultipartFile.fromFile(pickedPath,
            filename: pickedPath.split('/').last),
      });
      final r = await ref.read(apiClientProvider).dio.post('/qassobs/me/photos/', data: form);
      final ok = (r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300);
      if (!ok) {
        final detail = (r.data is Map && r.data['detail'] is String)
            ? r.data['detail'] as String : 'HTTP ${r.statusCode}';
        messenger.showSnackBar(SnackBar(content: Text(detail)));
        setState(() => _saving = false);
        return;
      }
      messenger.showSnackBar(const SnackBar(content: Text('Rasm yuklandi')));
      ref.invalidate(qassobMeProvider);
    } on DioException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message ?? 'Xato')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deletePhoto(int photoId) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).dio.delete('/qassobs/me/photos/$photoId/');
      messenger.showSnackBar(const SnackBar(content: Text("O'chirildi")));
      ref.invalidate(qassobMeProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(qassobMeProvider);
    final cs = Theme.of(context).colorScheme;
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString(), style: TextStyle(color: cs.error))),
      data: (m) {
        if (m == null) {
          return const Center(child: Padding(padding: EdgeInsets.all(24),
              child: Text("Profil topilmadi — onboardingdan o'tib chiqing.",
                  textAlign: TextAlign.center)));
        }
        _hydrate(m);
        final gallery = ((m['gallery'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map)).toList();
        return Stack(children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              _SectionCard(
                title: 'Men haqimda',
                hint: 'Buyer sizning haqingizda bu yerda o\'qiydi. Xo\'jaligingiz, tajribangiz, '
                      'oilangizning kasbi haqida 3-5 jumla yozing.',
                child: TextField(controller: _bioCtrl, maxLines: 5, maxLength: 2000,
                    decoration: const InputDecoration(
                        hintText: 'Salom! Men 10 yildan beri qassobchilik bilan shug\'ullanaman…',
                        border: OutlineInputBorder()))),
              _SectionCard(
                title: 'Mutaxassisliklar',
                hint: 'Sizning xizmatingizning kuchli tomonlari — masalan: Qurbonlik, Halal, '
                      'To\'y go\'shti, Ekspress so\'yish, Ulgurji yetkazib berish.',
                child: _ChipEditor(values: _specialties,
                    onAdd: (v) => setState(() => _specialties.add(v)),
                    onRemove: (i) => setState(() => _specialties.removeAt(i)))),
              _SectionCard(
                title: 'Tillar',
                hint: 'Buyer qaysi tilda gaplashishni biladi.',
                child: _LanguageChips(selected: _languages,
                    onToggle: (code) => setState(() {
                      if (_languages.contains(code)) { _languages.remove(code); }
                      else { _languages.add(code); }
                    }))),
              _SectionCard(
                title: 'Ish vaqti',
                hint: 'Har bir kun uchun ochilish/yopilish vaqti. Yopiq kunlarni "Dam" deb belgilang.',
                child: _WorkingHoursEditor(hours: _hours, onChanged: () => setState(() {}))),
              _SectionCard(
                title: 'Galereya',
                hint: 'Ish joyingiz, asboblar, hayvonlar rasmlari. Birinchi rasm asosiy ko\'rinadi.',
                child: _GalleryEditor(gallery: gallery,
                    onAdd: () => _pickAndUploadPhoto(0),
                    onDelete: _deletePhoto)),
              if (_saveError != null) Padding(padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                  child: Text(_saveError!, style: TextStyle(color: cs.error))),
            ]),
          // Sticky bottom save button — only saves text/JSON fields, gallery actions are immediate.
          Positioned(left: 16, right: 16, bottom: 16,
            child: SafeArea(top: false,
              child: FilledButton(onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: Colors.white))
                    : const Text('Saqlash', style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800))))),
        ]);
      },
    );
  }
}


// ============================================================================
// Helpers + sub-widgets — kept in the same file because they're not reused
// elsewhere and the screen reads top-to-bottom that way.
// ============================================================================

class _HourRange {
  final int open;
  final int close;
  const _HourRange(this.open, this.close);
}


class _SectionCard extends StatelessWidget {
  final String title;
  final String hint;
  final Widget child;
  const _SectionCard({required this.title, required this.hint, required this.child});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(hint, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 12),
        child,
      ]));
  }
}


/// Editable list of free-form short-string chips. Tap a chip to delete it; the "+ Qo'shish" chip at
/// the end pops a text input dialog. Used for Mutaxassisliklar.
class _ChipEditor extends StatelessWidget {
  final List<String> values;
  final ValueChanged<String> onAdd;
  final ValueChanged<int> onRemove;
  const _ChipEditor({required this.values, required this.onAdd, required this.onRemove});

  Future<void> _prompt(BuildContext context) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Yangi qo'shish"),
        content: TextField(controller: ctrl, autofocus: true,
            decoration: const InputDecoration(hintText: 'Qurbonlik')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Bekor')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text("Qo'shish")),
        ]));
    if (result != null && result.isNotEmpty) onAdd(result);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(spacing: 8, runSpacing: 8, children: [
      ...List.generate(values.length, (i) {
        return InputChip(label: Text(values[i]),
            onDeleted: () => onRemove(i),
            backgroundColor: cs.primary.withValues(alpha: 0.10));
      }),
      ActionChip(label: const Text("+ Qo'shish"),
          onPressed: () => _prompt(context),
          backgroundColor: Colors.white,
          side: BorderSide(color: cs.outlineVariant)),
    ]);
  }
}


/// 4-language toggle row. Uzbek + Russian are pre-emphasized as the common case for Tashkent
/// region; English + Tajik are optional but visible.
class _LanguageChips extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  const _LanguageChips({required this.selected, required this.onToggle});

  static const _langs = [
    ('uz', "O'zbekcha"), ('ru', 'Русский'), ('en', 'English'), ('tg', 'Tojikcha'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(spacing: 8, runSpacing: 8, children: _langs.map((row) {
      final code = row.$1; final label = row.$2;
      final on = selected.contains(code);
      return GestureDetector(onTap: () => onToggle(code),
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: on ? cs.primary : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: on ? cs.primary : cs.outlineVariant)),
          child: Text(label, style: TextStyle(fontWeight: FontWeight.w700,
              color: on ? cs.onPrimary : cs.onSurface))));
    }).toList());
  }
}


/// Per-weekday open/close hour pickers + a "Dam" (closed) toggle. Tap an hour cell to open Flutter's
/// showTimePicker; only the hour part is kept (we don't bother with minute granularity for v1).
class _WorkingHoursEditor extends StatelessWidget {
  final Map<String, _HourRange?> hours;
  final VoidCallback onChanged;
  const _WorkingHoursEditor({required this.hours, required this.onChanged});

  static const _dayLabels = [
    ('mon', 'Du'), ('tue', 'Se'), ('wed', 'Ch'), ('thu', 'Pa'),
    ('fri', 'Ju'), ('sat', 'Sh'), ('sun', 'Ya'),
  ];

  Future<void> _pickHour(BuildContext ctx, String day, bool isOpen) async {
    final current = hours[day];
    final initial = TimeOfDay(
        hour: isOpen ? (current?.open ?? 9) : (current?.close ?? 18), minute: 0);
    final picked = await showTimePicker(context: ctx, initialTime: initial,
        builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: child!));
    if (picked == null) return;
    final newRange = isOpen
        ? _HourRange(picked.hour, (current?.close ?? 18))
        : _HourRange((current?.open ?? 9), picked.hour);
    if (newRange.open >= newRange.close) return;
    hours[day] = newRange;
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(children: _dayLabels.map((entry) {
      final day = entry.$1; final label = entry.$2;
      final h = hours[day];
      final closed = h == null;
      return Padding(padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(width: 36, child: Text(label,
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w800))),
          const SizedBox(width: 8),
          if (closed)
            Expanded(child: Text('Dam',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)))
          else ...[
            _HourCell(value: '${h.open.toString().padLeft(2, '0')}:00',
                onTap: () => _pickHour(context, day, true)),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text('–')),
            _HourCell(value: '${h.close.toString().padLeft(2, '0')}:00',
                onTap: () => _pickHour(context, day, false)),
            const Spacer(),
          ],
          Switch.adaptive(value: !closed, onChanged: (v) {
            hours[day] = v ? const _HourRange(9, 18) : null;
            onChanged();
          }),
        ]));
    }).toList());
  }
}


class _HourCell extends StatelessWidget {
  final String value;
  final VoidCallback onTap;
  const _HourCell({required this.value, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(border: Border.all(color: cs.outlineVariant),
            borderRadius: BorderRadius.circular(8)),
        child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700))));
  }
}


class _GalleryEditor extends StatelessWidget {
  final List<Map<String, dynamic>> gallery;
  final VoidCallback onAdd;
  final ValueChanged<int> onDelete;
  const _GalleryEditor({required this.gallery, required this.onAdd, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GridView.count(
      crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8,
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      children: [
        ...gallery.map((p) {
          final id = (p['id'] as num?)?.toInt() ?? 0;
          final url = (p['image_url'] as String?) ?? '';
          return Stack(fit: StackFit.expand, children: [
            ClipRRect(borderRadius: BorderRadius.circular(10),
                child: url.isEmpty
                    ? Container(color: cs.surfaceContainerLowest)
                    : Image.network(url, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: cs.surfaceContainerLowest))),
            Positioned(top: 4, right: 4,
              child: InkWell(onTap: () => onDelete(id),
                child: Container(padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Color(0xCC000000),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, size: 16, color: Colors.white)))),
          ]);
        }),
        // Add-photo tile — same size as the others so the grid stays uniform.
        InkWell(onTap: onAdd, borderRadius: BorderRadius.circular(10),
          child: Container(decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.outlineVariant)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.add_a_photo_outlined, color: cs.onSurfaceVariant),
              const SizedBox(height: 4),
              Text("Qo'shish", style: TextStyle(color: cs.onSurfaceVariant)),
            ]))),
      ]);
  }
}
