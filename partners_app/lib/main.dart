import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';

import 'core/auth/partner_auth_notifier.dart';
import 'core/push/fcm_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/partner_theme.dart';
import 'l10n/app_localizations.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // v3.9.12 — PartnerFcmService.initialize() also runs Firebase.initializeApp() + registers the
  // top-level background handler. Keeping the try/catch means the app still boots on machines
  // without google-services.json (dev + tests).
  await PartnerFcmService.initialize();
  runApp(const ProviderScope(child: PartnersApp()));
}


class PartnersApp extends ConsumerStatefulWidget {
  const PartnersApp({super.key});
  @override
  ConsumerState<PartnersApp> createState() => _PartnersAppState();
}


class _PartnersAppState extends ConsumerState<PartnersApp> {
  bool _fcmBound = false;

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeNotifierProvider);

    // Bind FCM to router once — must happen AFTER the router is constructed so tap-handlers can
    // navigate. Also re-run token registration whenever auth flips to Authenticated so the freshly
    // logged-in user's FCM token lands on the backend.
    if (!_fcmBound) {
      _fcmBound = true;
      final fcm = ref.read(partnerFcmServiceProvider);
      fcm.bindRouter(router);
      ref.listen(partnerAuthProvider, (prev, next) async {
        if (next is AuthAuthenticated && (prev is! AuthAuthenticated)) {
          await fcm.requestPermission();
          await fcm.registerCurrentToken();
          // Ensure the current app-open FCM token subscription is also picked up (handles the
          // case where token rotated between installs).
          FirebaseMessaging.instance.onTokenRefresh.listen((_) => fcm.registerCurrentToken());
        }
      });
    }

    return MaterialApp.router(
      title: "Go'sht Bozori Partners",
      debugShowCheckedModeBanner: false,
      theme: PartnerTheme.light,
      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
      // Global messenger key so PartnerFcmService can pop SnackBars from any screen without
      // needing a BuildContext parameter — critical for the FCM onMessage callback path.
      scaffoldMessengerKey: PartnerFcmService.messengerKey,
    );
  }
}
