import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';


/// Sticky amber banner shown until the partner is is_verified=True. No KYC upload flow — superadmins
/// verify partners directly from Django admin, so the banner is informational only (no CTA).
class VerificationBanner extends StatelessWidget {
  const VerificationBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    return Container(color: const Color(0xFFFFF4E5),
      child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
        ])));
  }
}
