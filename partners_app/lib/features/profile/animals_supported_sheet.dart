import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/providers.dart';
import '../../l10n/app_localizations.dart';


/// Dedicated "Sotadigan go'shtlar" sheet. Pulled out of the Edit Profile sheet because suppliers
/// kept missing the chips in there — a separate Profil row makes it discoverable. Drives the
/// category chip filter on the Yangi tovar qo'shish page.
///
/// Reads current animals_supported from `/suppliers/me/` on open so chips show the supplier's
/// existing selection; PATCHes the new set back on save. Pops `true` when the save succeeds so the
/// caller can refresh local copies of the profile.
Future<bool> showAnimalsSupportedSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AnimalsSheet(),
  );
  return result ?? false;
}


class _AnimalsSheet extends ConsumerStatefulWidget {
  const _AnimalsSheet();
  @override
  ConsumerState<_AnimalsSheet> createState() => _AnimalsSheetState();
}


class _AnimalsSheetState extends ConsumerState<_AnimalsSheet> {
  static const _codes = ['MOL', 'QOY', 'ECHKI', 'OT', 'TOVUQ'];

  Set<String> _selected = {};
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ref.read(apiClientProvider).dio.get('/suppliers/me/');
      if (r.data is Map && r.data['animals_supported'] is List) {
        final raw = (r.data['animals_supported'] as List)
            .map((e) => e.toString().toUpperCase()).toSet();
        if (mounted) setState(() { _selected = raw; _loading = false; });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() { _submitting = true; _error = null; });
    HapticFeedback.selectionClick();
    try {
      await ref.read(apiClientProvider).dio.patch('/suppliers/me/',
          data: {'animals_supported': _selected.toList()});
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() { _submitting = false; _error = e.toString(); });
    }
  }

  String _animalLabel(AppLocalizations t, String code) {
    switch (code) {
      case 'MOL': return t.animalMol;
      case 'QOY': return t.animalQoy;
      case 'ECHKI': return t.animalEchki;
      case 'OT': return t.animalOt;
      case 'TOVUQ': return t.animalTovuq;
      default: return code;
    }
  }

  String _sheetTitle(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    if (lang == 'ru') return 'Какое мясо вы продаёте?';
    if (lang == 'en') return 'Which meat do you sell?';
    return 'Qaysi go\'shtlarni sotasiz?';
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
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 40, height: 4,
                  margin: const EdgeInsets.only(top: 6, bottom: 16),
                  decoration: BoxDecoration(color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2)))),
              Text(_sheetTitle(context),
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(t.onboardingAnimalsHint,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 18),
              if (_loading)
                const Padding(padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()))
              else
                Wrap(spacing: 8, runSpacing: 8, children: _codes.map((code) {
                  final on = _selected.contains(code);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (on) { _selected.remove(code); } else { _selected.add(code); }
                    }),
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: on ? cs.primary : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: on ? cs.primary : cs.outlineVariant)),
                      child: Text(_animalLabel(t, code),
                          style: TextStyle(fontWeight: FontWeight.w700,
                              color: on ? cs.onPrimary : cs.onSurface))));
                }).toList()),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: TextStyle(color: cs.error))),
              const SizedBox(height: 22),
              FilledButton(onPressed: (_loading || _submitting) ? null : _save,
                child: _submitting
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: Colors.white))
                    : Text(t.save)),
            ]))),
      ),
    );
  }
}
