// Login screen widget tests — render, validation, and submit-button state.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meat_marketplace/core/theme/app_theme.dart';
import 'package:meat_marketplace/features/auth/presentation/login_screen.dart';
import 'package:meat_marketplace/l10n/app_localizations.dart';


/// Helper — wraps the LoginScreen in a minimal MaterialApp + ProviderScope so it can be pumped in isolation.
Widget _wrap({Locale locale = const Locale('en')}) => ProviderScope(child: MaterialApp(
      locale: locale, supportedLocales: const [Locale('en'), Locale('uz'), Locale('ru')],
      localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate,
                                     GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      theme: AppTheme.light,
      home: const LoginScreen(),
    ));


void main() {
  testWidgets('renders title, both fields, and submit button (English)', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsAtLeast(1));    // appears as both title and button label
    // Two TextFormFields: email + password
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets('renders Uzbek title when locale is uz', (tester) async {
    await tester.pumpWidget(_wrap(locale: const Locale('uz')));
    await tester.pumpAndSettle();
    expect(find.text('Kirish'), findsAtLeast(1));
    expect(find.text("Go'sht Bozoriga xush kelibsiz"), findsOneWidget);
  });

  testWidgets('shows validation errors when submitting empty form', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    // Both fields fail validation — email "Enter a valid email" + password "Min 8 characters"
    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(find.text('Min 8 characters'), findsOneWidget);
  });
}
