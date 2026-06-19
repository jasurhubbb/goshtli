import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';

import '../../l10n/app_localizations.dart';

/// First-run language picker. Three big cards (UZ/RU/EN). Picking writes to `shared_core`'s
/// localeNotifier — same SharedPreferences key the buyer app uses, so a user with both apps gets
/// consistent language across them.
class LanguagePickerScreen extends ConsumerWidget {
  const LanguagePickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 24),
          Text(t.languagePickerTitle, style: tt.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 32),
          Expanded(child: Column(children: [
            _LangCard(label: t.languageUz, native: "O'zbekcha", emoji: "🇺🇿",
              onTap: () => _pick(ref, context, const Locale('uz'))),
            const SizedBox(height: 14),
            _LangCard(label: t.languageRu, native: "Русский", emoji: "🇷🇺",
              onTap: () => _pick(ref, context, const Locale('ru'))),
            const SizedBox(height: 14),
            _LangCard(label: t.languageEn, native: "English", emoji: "🇬🇧",
              onTap: () => _pick(ref, context, const Locale('en'))),
          ])),
          Text(t.appTitle, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center),
        ]))));
  }

  void _pick(WidgetRef ref, BuildContext context, Locale locale) async {
    HapticFeedback.selectionClick();
    await ref.read(localeNotifierProvider.notifier).set(locale);
    if (context.mounted) context.go('/role-pick');
  }
}


class _LangCard extends StatelessWidget {
  final String label;
  final String native;
  final String emoji;
  final VoidCallback onTap;
  const _LangCard({required this.label, required this.native, required this.emoji,
                    required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(color: Colors.white, borderRadius: BorderRadius.circular(20),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20),
        child: Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5))),
          child: Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 36)),
            const SizedBox(width: 18),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              Text(native, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            ])),
            Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
          ]))));
  }
}
