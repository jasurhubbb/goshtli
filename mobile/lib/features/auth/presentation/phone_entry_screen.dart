// PhoneEntryScreen — single-page phone capture for the v3.2 unified login/signup flow.
//
// UX: one input — 9 digits after a fixed "+998" prefix — and one giant CTA. On submit we hit
// /auth/phone-check/:
//   • exists → call phoneLogin → router redirects to '/' once auth state flips to AuthAuthenticated
//   • new    → push '/auth/details' with the phone in `extra`, where the user types their name (+ optional business)
//
// The local 9 digits are formatted as the user types: `XX XXX-XX-XX` (operator + 3-2-2 subscriber). The
// controller stores the FORMATTED text so the user sees the dashes; submit() strips non-digits before sending
// to the backend (which expects raw `+998XXXXXXXXX` per its `^\+[0-9]{10,15}$` regex).
//
// Layout: content scrolls when the keyboard pushes it; the "Davom etish" CTA is pinned in a non-scrolling
// footer above the keyboard inset so it's always visible (the old `Spacer()`-based layout pushed it off
// the bottom edge once the soft keyboard came up).
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
  bool _submitting = false;
  String? _error;

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  /// Raw digits-only view of the controller. Used for length checks + the submit payload — the controller's
  /// own text includes spaces and hyphens for display.
  String get _rawDigits => _controller.text.replaceAll(RegExp(r'\D'), '');
  bool get _valid => _rawDigits.length == _localDigits;

  Future<void> _submit() async {
    if (!_valid || _submitting) return;
    final fullPhone = '$_dialCode$_rawDigits';                // backend regex expects pure digits after +
    setState(() { _submitting = true; _error = null; });
    try {
      final exists = await ref.read(authNotifierProvider.notifier).phoneCheck(fullPhone);
      if (!mounted) return;
      if (exists) {
        await ref.read(authNotifierProvider.notifier).phoneLogin(fullPhone);
      } else {
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
    final authLoading = ref.watch(authNotifierProvider) is AuthLoading;
    final loading = _submitting || authLoading;

    return Scaffold(
      appBar: AppBar(elevation: 0, backgroundColor: Colors.transparent, actions: const [LanguagePicker()]),
      // resizeToAvoidBottomInset = true by default — but combined with the fixed-footer layout below it now
      // shrinks ONLY the scrollable area, leaving the CTA pinned where the user can always tap it.
      body: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ---- Scrollable top section (title + input + error) ----
        // Wrapped in Expanded so it gives up space to the keyboard, then SingleChildScrollView so the user
        // can still reach the field if their device is short.
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(height: 32),
            Text(t.phoneAuthTitle, style: tt.displayMedium),
            const SizedBox(height: 8),
            Text(t.phoneAuthSubtitle, style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 40),
            Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(children: [
                Text(_dialCode, style: tt.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600, color: cs.onSurface)),
                const SizedBox(width: 12),
                Container(width: 1, height: 28, color: cs.outlineVariant),
                const SizedBox(width: 12),
                Expanded(child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.phone,
                  autofocus: true,
                  style: tt.headlineSmall,
                  cursorHeight: 28,
                  inputFormatters: [
                    // Strip non-digits + auto-insert spaces/dashes as the user types. The controller text
                    // ends up as "90 123-45-67" but _rawDigits / _valid read through the formatting.
                    _UzPhoneFormatter(),
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
          ]),
        )),
        // ---- Pinned footer: CTA always visible regardless of keyboard / screen size ----
        // Padding accounts for the keyboard (viewInsets) — when it's hidden we fall back to a 24pt bottom margin.
        Padding(padding: EdgeInsets.fromLTRB(24, 8, 24,
            MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 24),
          child: SizedBox(height: 56, child: FilledButton(
            onPressed: (_valid && !loading) ? _submit : null,
            style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            child: loading
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : Text(t.phoneAuthContinue, style: tt.titleMedium?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          )),
        ),
      ])),
    );
  }
}


/// Uzbek phone input formatter — turns raw key presses into `XX XXX-XX-XX` (9 digits = operator code
/// (2) + subscriber (3-2-2)). Matches the format Uzum / Click / most Uz banking apps use.
///
/// Algorithm:
///   1. Strip every non-digit from the incoming value (handles paste-from-clipboard cases too)
///   2. Truncate to 9 digits — anything past that is silently dropped
///   3. Reinsert separators at digit positions 2 (space), 5 (hyphen), 7 (hyphen)
///   4. Re-anchor the cursor to the end of the formatted string (good enough for an authenticator field
///      where users don't typically mid-edit a phone number)
class _UzPhoneFormatter extends TextInputFormatter {
  static const int _maxDigits = 9;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final truncated = digits.length > _maxDigits ? digits.substring(0, _maxDigits) : digits;
    final formatted = _format(truncated);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static String _format(String d) {
    if (d.length <= 2) return d;                              // "9", "90"
    if (d.length <= 5) return '${d.substring(0, 2)} ${d.substring(2)}';            // "90 123"
    if (d.length <= 7) return '${d.substring(0, 2)} ${d.substring(2, 5)}-${d.substring(5)}';  // "90 123-45"
    return '${d.substring(0, 2)} ${d.substring(2, 5)}-${d.substring(5, 7)}-${d.substring(7)}'; // "90 123-45-67"
  }
}
