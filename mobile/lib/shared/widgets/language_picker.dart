// LanguagePicker — small dropdown shown in the AppBar / login screen so users can switch language at any time.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/locale/locale_notifier.dart';
import '../../core/locale/locale_providers.dart';


/// Compact icon-style language selector — uses a PopupMenuButton to stay AppBar-friendly without taking horizontal space.
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
            // Flag-like prefix using the language code; emoji flags would require regional codes we don't have
            SizedBox(width: 32, child: Text(l.languageCode.toUpperCase(),
                style: TextStyle(fontWeight: l == current ? FontWeight.bold : FontWeight.normal))),
            Text(_displayName(l)),
          ])),
      ],
    );
  }

  /// Self-name each language in its own script so the user recognizes their language even when current locale is different.
  static String _displayName(Locale l) => switch (l.languageCode) {
        'en' => 'English', 'uz' => "O'zbekcha", 'ru' => 'Русский', _ => l.languageCode,
      };
}
