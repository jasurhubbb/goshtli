import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported locales — buyer + partner apps both render in UZ / RU / EN.
/// Code 'uz' targets Uzbek Latin (default for Uzbekistan B2B).
const supportedLocales = [
  Locale('uz'),
  Locale('ru'),
  Locale('en'),
];

const _kLocaleKey = 'locale';

/// LocaleNotifier — persists the active locale to SharedPreferences and exposes it to MaterialApp.
///
/// Both apps consume the same SP key so a user who switches language in the buyer app sees the same
/// language in the partners app on next open.
class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('uz')) { _load(); }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final code = p.getString(_kLocaleKey);
    if (code != null && supportedLocales.any((l) => l.languageCode == code)) {
      state = Locale(code);
    }
  }

  Future<void> set(Locale next) async {
    state = next;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLocaleKey, next.languageCode);
  }
}


final localeNotifierProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) => LocaleNotifier());
