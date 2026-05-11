// App entrypoint — wires Riverpod's ProviderScope around MaterialApp.router so go_router can read auth state from providers.
//
// Localization is wired here too: AppLocalizations.localizationsDelegates supplies translated strings; locale comes from the
// localeNotifierProvider so the picker in AppBar can swap languages live without a restart.
//
// v2 Milestone E.5 — Firebase Cloud Messaging is initialized before runApp. Failures are swallowed inside FcmService
// so the app still boots if google-services.json is missing or invalid (push just silently disabled).
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/locale/locale_notifier.dart';
import 'core/locale/locale_providers.dart';
import 'core/push/fcm_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_providers.dart';
import 'l10n/app_localizations.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FcmService.initialize();
  runApp(const ProviderScope(child: MeatMarketplaceApp()));
}


/// Root — uses MaterialApp.router because we route via go_router. The router itself is a Riverpod provider so it auto-rebuilds on auth changes.
class MeatMarketplaceApp extends ConsumerWidget {
  const MeatMarketplaceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeNotifierProvider);
    final router = ref.watch(routerProvider);
    // Hand the router to FcmService so notification taps can navigate. The bind method is idempotent — calling on
    // every rebuild only swaps the pointer; listeners attach once on the first call.
    ref.read(fcmServiceProvider).bindRouter(router);
    return MaterialApp.router(
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appTitle,  // localize the OS task-switcher title too
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // Live-switchable locale — flipping localeNotifierProvider rebuilds MaterialApp with the new locale automatically
      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,    // material widgets (date pickers etc.)
        GlobalWidgetsLocalizations.delegate,      // base widgets (text direction)
        GlobalCupertinoLocalizations.delegate,    // any Cupertino widgets we add later
      ],
      routerConfig: router,
    );
  }
}
