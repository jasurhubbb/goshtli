// PrivacyTagline — renders the "By tapping you accept the privacy policy & terms of use" line with the two
// link phrases visually underlined. Built around a single ARB template (`privacyTagline`) plus two link-label keys
// (`privacyPolicyLink`, `termsOfUseLink`), so swapping locales rewrites the whole sentence — not just the labels.
//
// Design choice: we resolve the template by passing the link labels in as placeholder values, then split the
// resulting string back on those same labels to wrap them in TextSpans with link styling. This keeps grammar correct
// in suffix-based languages like Uzbek where the link noun has to be inflected ("shartlarini", not "shartlari"),
// while still letting us style only the noun phrase as a tappable link.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';


class PrivacyTagline extends StatefulWidget {
  /// Routes to invoke when the policy / terms link is tapped. Pass null to leave the label non-tappable
  /// (still styled as a link — matches the Instamart reference where the targets are decorative until policies ship).
  final VoidCallback? onPolicyTap;
  final VoidCallback? onTermsTap;
  const PrivacyTagline({super.key, this.onPolicyTap, this.onTermsTap});

  @override
  State<PrivacyTagline> createState() => _PrivacyTaglineState();
}


/// Stateful so we can own + dispose the two TapGestureRecognizers. Reusing recognizers per build avoids the
/// "TapGestureRecognizer was used after being disposed" assertion that hits when rebuilds create new spans.
class _PrivacyTaglineState extends State<PrivacyTagline> {
  final _policyRec = TapGestureRecognizer();
  final _termsRec = TapGestureRecognizer();

  @override
  void dispose() { _policyRec.dispose(); _termsRec.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    // Re-bind taps every build — callbacks can change as parent state changes
    _policyRec.onTap = widget.onPolicyTap;
    _termsRec.onTap = widget.onTermsTap;

    final policy = t.privacyPolicyLink;
    final terms = t.termsOfUseLink;
    // Resolve the locale-specific template with both link labels inlined.
    final full = t.privacyTagline(policy, terms);

    // Locate the two link substrings inside the resolved sentence. We find policy first, then search for terms
    // AFTER policy's end so an accidental substring overlap can't confuse the slicer.
    final iPolicy = full.indexOf(policy);
    final policyEnd = iPolicy + policy.length;
    final iTerms = full.indexOf(terms, policyEnd);
    // Defensive fallback — if either label is missing (corrupted translation), render the raw string in plain style
    // rather than crash. Localizers occasionally rewrite a label without updating its key.
    if (iPolicy < 0 || iTerms < 0) {
      return Text(full, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant), textAlign: TextAlign.center);
    }
    final base = tt.bodySmall?.copyWith(color: cs.onSurfaceVariant);
    final link = base?.copyWith(decoration: TextDecoration.underline, color: cs.onSurface,
        fontWeight: FontWeight.w600);

    return Text.rich(TextSpan(style: base, children: [
      TextSpan(text: full.substring(0, iPolicy)),
      TextSpan(text: policy, style: link, recognizer: widget.onPolicyTap != null ? _policyRec : null),
      TextSpan(text: full.substring(policyEnd, iTerms)),
      TextSpan(text: terms, style: link, recognizer: widget.onTermsTap != null ? _termsRec : null),
      TextSpan(text: full.substring(iTerms + terms.length)),
    ]), textAlign: TextAlign.center);
  }
}
