// Smoke test — verifies the root tree builds without throwing under ProviderScope. Real screen tests live alongside each feature.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meat_marketplace/main.dart';

void main() {
  testWidgets('App boots into MaterialApp.router without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MeatMarketplaceApp()));
    // We can't pumpAndSettle here — flutter_secure_storage isn't backed in tests, so AuthNotifier sits in AuthInitial → splash.
    // Just confirm the router wired up MaterialApp; deeper assertions belong in feature-specific tests.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
