// Pure-Dart tests for the enum-label l10n extensions. Verifies every enum value resolves to a non-empty string per locale.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meat_marketplace/l10n/app_localizations.dart';
import 'package:meat_marketplace/shared/l10n/enum_labels.dart';
import 'package:meat_marketplace/shared/models/listing.dart';
import 'package:meat_marketplace/shared/models/order.dart' as model;

/// Builds a throwaway widget tree just to grab a BuildContext with the right localization delegates.
Future<BuildContext> _contextFor(WidgetTester tester, Locale locale) async {
  late BuildContext captured;
  await tester.pumpWidget(MaterialApp(
    locale: locale, supportedLocales: const [Locale('en'), Locale('uz'), Locale('ru')],
    localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate,
                                   GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    home: Builder(builder: (ctx) { captured = ctx; return const SizedBox(); }),
  ));
  await tester.pumpAndSettle();
  return captured;
}


void main() {
  testWidgets('every MeatType resolves to non-empty label in en/uz/ru', (tester) async {
    for (final loc in [const Locale('en'), const Locale('uz'), const Locale('ru')]) {
      final ctx = await _contextFor(tester, loc);
      for (final v in MeatType.values) {
        expect(v.label(ctx), isNotEmpty, reason: 'MeatType.$v has no label in ${loc.languageCode}');
      }
    }
  });

  testWidgets('every ListingStatus resolves to non-empty label in en/uz/ru', (tester) async {
    for (final loc in [const Locale('en'), const Locale('uz'), const Locale('ru')]) {
      final ctx = await _contextFor(tester, loc);
      for (final v in ListingStatus.values) {
        expect(v.label(ctx), isNotEmpty, reason: 'ListingStatus.$v has no label in ${loc.languageCode}');
      }
    }
  });

  testWidgets('every OrderStatus resolves to non-empty label in en/uz/ru', (tester) async {
    for (final loc in [const Locale('en'), const Locale('uz'), const Locale('ru')]) {
      final ctx = await _contextFor(tester, loc);
      for (final v in model.OrderStatus.values) {
        expect(v.label(ctx), isNotEmpty, reason: 'OrderStatus.$v has no label in ${loc.languageCode}');
      }
    }
  });

  testWidgets('Uzbek labels differ from English (sanity that translations actually applied)', (tester) async {
    final en = await _contextFor(tester, const Locale('en'));
    final beefEn = MeatType.beef.label(en);
    final uz = await _contextFor(tester, const Locale('uz'));
    final beefUz = MeatType.beef.label(uz);
    expect(beefEn, isNot(equals(beefUz)));  // 'Beef' vs "Mol go'shti"
  });
}
