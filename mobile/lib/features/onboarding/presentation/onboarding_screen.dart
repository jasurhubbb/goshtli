// OnboardingScreen — first-run welcome + location permission. After grant OR skip, marks onboarding done and
// routes to home. No login wall.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/location/location_providers.dart';
import '../../../l10n/app_localizations.dart';


class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}


class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _requesting = false;

  /// Walks the user through the OS permission prompt (or skip), persists the result, and routes to home.
  Future<void> _continue({required bool ask}) async {
    setState(() => _requesting = true);
    final svc = ref.read(locationServiceProvider);
    if (ask) await svc.requestAndFetch();           // null result is fine — user can skip
    await svc.markOnboardingDone();
    // Re-evaluate the router redirect by invalidating the onboarding flag provider
    ref.invalidate(onboardingDoneProvider);
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Spacer(),
          // Iconography stand-in for the brand mark — replaced by a 3D illustration later
          Icon(Icons.location_on_outlined, size: 96, color: cs.primary),
          const SizedBox(height: 24),
          Text(t.onbLocationTitle, style: tt.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(t.onbLocationBody, style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
               textAlign: TextAlign.center),
          const Spacer(),
          FilledButton.icon(
            icon: const Icon(Icons.location_searching),
            onPressed: _requesting ? null : () => _continue(ask: true),
            label: _requesting
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(t.onbDetectLocation)),
          const SizedBox(height: 12),
          TextButton(onPressed: _requesting ? null : () => _continue(ask: false),
            child: Text(t.onbNotNow)),
        ]))),
    );
  }
}
