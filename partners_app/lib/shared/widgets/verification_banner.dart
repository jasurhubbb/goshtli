import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';


/// Sticky amber banner the dashboard shows until the partner is is_verified=True. Non-dismissible —
/// tap → KYC upload screen.
class VerificationBanner extends StatelessWidget {
  const VerificationBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    return Material(color: const Color(0xFFFFF4E5),
      child: InkWell(onTap: () => context.push('/kyc'),
        child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(children: [
            const Icon(Icons.shield_outlined, color: Color(0xFF8A4F00)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.verificationBannerTitle,
                  style: tt.titleSmall?.copyWith(color: const Color(0xFF8A4F00),
                      fontWeight: FontWeight.w800)),
              Text(t.verificationBannerBody,
                  style: tt.bodySmall?.copyWith(color: const Color(0xFF8A4F00))),
            ])),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF8A4F00)),
          ]))));
  }
}
