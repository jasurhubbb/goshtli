// LanguagePicker — AppBar icon dropdown for quick language swaps. Self-named so each language is recognizable
// in its own script even when the current locale is the other one.
//
// The Profile screen uses a different presentation (showLanguageSheet, defined below) — full-width bottom sheet
// with radio buttons and a "Davom eting" confirm button, matching the Uzum-style UX.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/locale/locale_notifier.dart';
import '../../core/locale/locale_providers.dart';
import '../../l10n/app_localizations.dart';


class LanguagePicker extends ConsumerWidget {
  const LanguagePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeNotifierProvider);
    return PopupMenuButton<Locale>(
      tooltip: _displayName(current),
      icon: const Icon(Icons.language),
      onSelected: (l) => ref.read(localeNotifierProvider.notifier).set(l),
      itemBuilder: (_) => [
        for (final l in supportedLocales) PopupMenuItem(value: l,
          child: Row(children: [
            SizedBox(width: 32, child: Text(l.languageCode.toUpperCase(),
                style: TextStyle(fontWeight: l == current ? FontWeight.bold : FontWeight.normal))),
            Text(_displayName(l)),
          ])),
      ],
    );
  }

  static String _displayName(Locale l) => switch (l.languageCode) {
        'uz' => "O'zbekcha", 'ru' => 'Русский', _ => l.languageCode,
      };
}


/// Bottom-sheet language picker — used from Profile screen's "Ilova tili" row. Big radio buttons + flag chip +
/// a primary "Davom eting" button, matching the Uzum / Instamart-style reference design.
Future<void> showLanguageSheet(BuildContext context, WidgetRef ref) async {
  final current = ref.read(localeNotifierProvider);
  // Local pick state — only commit to LocaleNotifier on "Davom eting" so cancel-by-swipe doesn't change the app
  Locale picked = current;
  await showModalBottomSheet(context: context, isScrollControlled: true, builder: (sctx) =>
    StatefulBuilder(builder: (sctx, setSheet) {
      final cs = Theme.of(sctx).colorScheme;
      final tt = Theme.of(sctx).textTheme;
      return Padding(padding: EdgeInsets.only(left: 24, right: 24, top: 8,
                                                bottom: MediaQuery.of(sctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(padding: const EdgeInsets.fromLTRB(0, 12, 0, 18),
            child: Text(AppLocalizations.of(sctx).pickLanguageTitle, style: tt.headlineSmall)),
          for (int i = 0; i < supportedLocales.length; i++) ...[
            _LanguageRow(
              locale: supportedLocales[i],
              selected: picked == supportedLocales[i],
              onTap: () => setSheet(() => picked = supportedLocales[i])),
            if (i < supportedLocales.length - 1) Divider(height: 1,
              color: cs.outlineVariant.withValues(alpha: 0.4)),
          ],
          const SizedBox(height: 32),
          FilledButton(onPressed: () async {
            await ref.read(localeNotifierProvider.notifier).set(picked);
            if (sctx.mounted) Navigator.pop(sctx);
          }, child: Text(AppLocalizations.of(sctx).continueAction)),
        ]));
    }));
}


/// One row in the bottom-sheet language picker — radio on left, language name in its own script, flag-style chip on right.
class _LanguageRow extends StatelessWidget {
  final Locale locale;
  final bool selected;
  final VoidCallback onTap;
  const _LanguageRow({required this.locale, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final name = switch (locale.languageCode) {
      'uz' => "O'zbekcha", 'ru' => 'Русский', _ => locale.languageCode };
    final flagEmoji = switch (locale.languageCode) {
      'uz' => '🇺🇿', 'ru' => '🇷🇺', _ => '🏳️' };
    return InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(children: [
        // Radio (custom — Material's Radio<Locale> doesn't size match the spec)
        Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
             color: selected ? cs.primary : cs.outlineVariant, size: 22),
        const SizedBox(width: 14),
        Expanded(child: Text(name, style: tt.titleMedium)),
        Text(flagEmoji, style: const TextStyle(fontSize: 22)),
      ])));
  }
}
