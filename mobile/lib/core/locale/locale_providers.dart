// Riverpod providers for the locale layer.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'locale_notifier.dart';
import 'locale_storage.dart';


final localeStorageProvider = Provider<LocaleStorage>((ref) => LocaleStorage());

final localeNotifierProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) =>
    LocaleNotifier(ref.watch(localeStorageProvider)));
