// PhoneEntryScreen — phone capture for the v3.9.16 Telegram-phone-verification signup/login flow.
//
// Flow (replaces Firebase SMS in v3.4):
//   • User types their +998 number, taps "Davom etish".
//   • We POST /auth/telegram/start/ → backend opens a verification session and returns a session token +
//     the t.me deep link. We push /auth/otp (the code screen) with {phone, sessionToken, botUrl}.
//   • On the code screen the user taps "Botga o'tish", shares their contact in the bot, gets a 6-digit code,
//     comes back and enters it. No SMS, no Firebase.
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
  static const String _dialCode = '+998';
  static const int _localDigits = 9;
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  String get _rawDigits => _controller.text.replaceAll(RegExp(r'\D'), '');
  bool get _valid => _rawDigits.length == _localDigits;

  Future<void> _submit() async {
    if (!_valid || _submitting) return;
    final fullPhone = '$_dialCode$_rawDigits';
    setState(() { _submitting = true; _error = null; });
    try {
      // Open a Telegram verification session. Backend returns the session token (used on verify) + the
      // deep-link URL the code screen's "Botga o'tish" button opens.
      final started = await ref.read(authRepositoryProvider).telegramStart(fullPhone);
      if (!mounted) return;
      context.push('/auth/otp', extra: {
        'phone': fullPhone,
        'sessionToken': started.sessionToken,
        'botUrl': started.botUrl,
      });
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
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
      body: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
                  inputFormatters: [_UzPhoneFormatter()],
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


// ---------- Helpers ----------

/// Uzbek phone formatter — turns raw digits into XX XXX-XX-XX as the user types.
class _UzPhoneFormatter extends TextInputFormatter {
  static const int _maxDigits = 9;
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final truncated = digits.length > _maxDigits ? digits.substring(0, _maxDigits) : digits;
    final formatted = _format(truncated);
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
  static String _format(String d) {
    if (d.length <= 2) return d;
    if (d.length <= 5) return '${d.substring(0, 2)} ${d.substring(2)}';
    if (d.length <= 7) return '${d.substring(0, 2)} ${d.substring(2, 5)}-${d.substring(5)}';
    return '${d.substring(0, 2)} ${d.substring(2, 5)}-${d.substring(5, 7)}-${d.substring(7)}';
  }
}
