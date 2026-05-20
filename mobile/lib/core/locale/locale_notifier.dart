// LocaleNotifier — single source of truth for the active language.
//
// v3 pivot: the app ships in Uzbek + Russian only. English is the ARB template (Flutter requires one) but is
// NOT user-selectable. Default is Uzbek regardless of the OS locale — our market is Uzbek-first.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'locale_storage.dart';


/// Locales the user can pick. Order here drives the order in the language picker.
const supportedLocales = [Locale('uz'), Locale('ru')];


class LocaleNotifier extends StateNotifier<Locale> {
  final LocaleStorage _storage;
  LocaleNotifier(this._storage) : super(const Locale('uz')) { _load(); }

  /// Hydrate from disk on app start; if a stored value exists and is supported, override the Uzbek default.
  Future<void> _load() async {
    final code = await _storage.read();
    if (code == null) return;
    final match = supportedLocales.where((l) => l.languageCode == code).firstOrNull;
    if (match != null) state = match;
  }

  /// Persist + emit. Called from the language picker UI.
  Future<void> set(Locale locale) async {
    if (!supportedLocales.contains(locale)) return;
    state = locale;
    await _storage.write(locale.languageCode);
  }
}
