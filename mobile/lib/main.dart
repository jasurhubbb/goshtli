// App entrypoint — wires Riverpod's ProviderScope around MaterialApp.router so go_router can read auth state from providers.
//
// Localization is wired here too: AppLocalizations.localizationsDelegates supplies translated strings; locale comes from the
// localeNotifierProvider so the picker in AppBar can swap languages live without a restart.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/locale/locale_notifier.dart';
import 'core/locale/locale_providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';

void main() => runApp(const ProviderScope(child: MeatMarketplaceApp()));


/// Root — uses MaterialApp.router because we route via go_router. The router itself is a Riverpod provider so it auto-rebuilds on auth changes.
class MeatMarketplaceApp extends ConsumerWidget {
  const MeatMarketplaceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeNotifierProvider);
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
      routerConfig: ref.watch(routerProvider),
    );
  }
}
