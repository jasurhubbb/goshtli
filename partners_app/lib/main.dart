import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';

import 'core/router/app_router.dart';
import 'core/theme/partner_theme.dart';
import 'l10n/app_localizations.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase init is required for Phone Auth + FCM. Options come from android/google-services.json
  // (committed by `flutterfire configure`) — partner app reuses the same Firebase project as the buyer
  // app so test phone numbers + service-account credentials are shared.
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Allow the app to boot without Firebase in case google-services.json hasn't been added yet.
    // Phone OTP screens will throw at use-time; everything else (locale, role pick, UI) still works.
  }
  runApp(const ProviderScope(child: PartnersApp()));
}


class PartnersApp extends ConsumerWidget {
  const PartnersApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeNotifierProvider);
    return MaterialApp.router(
      title: "Go'sht Bozori Partners",
      debugShowCheckedModeBanner: false,
      theme: PartnerTheme.light,
      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
    );
  }
}
