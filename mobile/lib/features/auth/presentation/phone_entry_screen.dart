// PhoneEntryScreen — single-page phone capture for the v3.2 unified login/signup flow.
//
// UX: one input — 9 digits after a fixed "+998" prefix — and one giant CTA. On submit we hit
// /auth/phone-check/:
//   • exists → call phoneLogin → router redirects to '/' once auth state flips to AuthAuthenticated
//   • new    → push '/auth/details' with the phone in `extra`, where the user types their name (+ optional business)
//
// We intentionally DO NOT auto-format the digits with spaces in the controller — we keep raw digits internally
// and render the "+998" prefix as a sibling label outside the TextField. This avoids ambiguity between visual
// spacing and stored value (which is what the backend regex /^\+[0-9]{10,15}$/ validates).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/language_picker.dart';
import '../data/auth_repository.dart';
import '../providers/auth_providers.dart';
import '../providers/auth_state.dart';


class PhoneEntryScreen extends ConsumerStatefulWidget {
  const PhoneEntryScreen({super.key});
  @override
  ConsumerState<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}


class _PhoneEntryScreenState extends ConsumerState<PhoneEntryScreen> {
  static const String _dialCode = '+998';                    // Uzbekistan, hard-coded for v3.2 (only market we ship to)
  static const int _localDigits = 9;                          // Uz mobile numbers after the country code
  final _controller = TextEditingController();
  bool _submitting = false;                                   // local spinner — auth state spins for login leg only
  String? _error;                                             // inline error for invalid phone OR API failure

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  bool get _valid => _controller.text.length == _localDigits;

  Future<void> _submit() async {
    if (!_valid || _submitting) return;
    final fullPhone = '$_dialCode${_controller.text}';        // server expects +<country><local> as one string
    setState(() { _submitting = true; _error = null; });
    try {
      final exists = await ref.read(authNotifierProvider.notifier).phoneCheck(fullPhone);
      if (!mounted) return;
      if (exists) {
        // Existing user → trigger login. Router redirect handles navigation when state flips to AuthAuthenticated.
        await ref.read(authNotifierProvider.notifier).phoneLogin(fullPhone);
      } else {
        // New user → carry the phone forward to the name screen.
        context.push('/auth/details', extra: {'phone': fullPhone});
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    // Combine the local _submitting flag with the AuthNotifier's AuthLoading so we don't render the button
    // active during the phoneLogin leg (the router redirects on completion, but until then we want the spinner).
    final authLoading = ref.watch(authNotifierProvider) is AuthLoading;
    final loading = _submitting || authLoading;

    return Scaffold(
      // Transparent app bar — only the language picker; the hero owns the visual weight, matching the previous design.
      appBar: AppBar(elevation: 0, backgroundColor: Colors.transparent, actions: const [LanguagePicker()]),
      body: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 32),
          Text(t.phoneAuthTitle, style: tt.displayMedium),
          const SizedBox(height: 8),
          Text(t.phoneAuthSubtitle,
              style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 40),
          // Phone input: "+998" pinned as prefix label, then a 9-digit field with big readable type.
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(children: [
              // Static dial code — not editable. Visually weighted to feel part of the field.
              Text(_dialCode, style: tt.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600, color: cs.onSurface)),
              const SizedBox(width: 12),
              Container(width: 1, height: 28, color: cs.outlineVariant),  // hairline divider between prefix + input
              const SizedBox(width: 12),
              Expanded(child: TextField(
                controller: _controller,
                keyboardType: TextInputType.phone,
                autofocus: true,                                                 // keyboard up immediately on screen open
                style: tt.headlineSmall,
                cursorHeight: 28,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,                        // hard block any non-digit input
                  LengthLimitingTextInputFormatter(_localDigits),                // can't overflow past 9 chars
                ],
                onChanged: (_) { if (_error != null) setState(() => _error = null); },
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  border: InputBorder.none, enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none, isCollapsed: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  hintText: t.phoneAuthHint,
                  hintStyle: tt.headlineSmall?.copyWith(color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                ),
              )),
            ]),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: tt.bodyMedium?.copyWith(color: cs.error))),
          const Spacer(),                                                   // pushes the CTA to bottom — phone-call shape
          // Big rounded primary CTA — disabled until 9 digits entered. Same look as the Uzum-ish flow.
          SizedBox(height: 56, child: FilledButton(
            onPressed: (_valid && !loading) ? _submit : null,
            style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            child: loading
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : Text(t.phoneAuthContinue, style: tt.titleMedium?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          )),
          const SizedBox(height: 8),
        ]),
      )),
    );
  }
}
