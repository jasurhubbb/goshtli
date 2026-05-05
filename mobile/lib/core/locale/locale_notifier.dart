// LocaleNotifier — single source of truth for the active language. Defaults to system locale on first run, falls back to Uzbek
// (the primary user audience) when the system locale isn't English / Russian / Uzbek.
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'locale_storage.dart';


/// Three locales we ship — keep in sync with the ARB files in lib/l10n/.
const supportedLocales = [Locale('en'), Locale('uz'), Locale('ru')];


class LocaleNotifier extends StateNotifier<Locale> {
  final LocaleStorage _storage;
  LocaleNotifier(this._storage) : super(_initial()) { _load(); }

  /// Pick a sensible default before we've read storage — whatever the OS reports if we support it, else Uzbek.
  static Locale _initial() {
    final sys = PlatformDispatcher.instance.locale.languageCode;
    return supportedLocales.firstWhere((l) => l.languageCode == sys, orElse: () => const Locale('uz'));
  }

  /// Hydrate from disk on app start; if a stored value exists and is supported, override the OS default.
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
