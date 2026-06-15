// PhoneEntryScreen — phone capture for the v3.4 Firebase-Phone-Auth signup/login flow.
//
// What changed from v3.2:
//   • OLD: tap "Davom etish" → /auth/phone-check/ (server replies exists/new) → either phone-login or push
//     /auth/details directly. No SMS, no proof the user owns the number — anyone could log in as anyone.
//   • NEW: tap "Davom etish" → FirebaseAuth.verifyPhoneNumber() → Firebase sends SMS → push /auth/otp with
//     the verificationId. The user proves ownership of the phone by entering the SMS code on /auth/otp.
//
// Two callbacks from verifyPhoneNumber matter to us:
//   • verificationCompleted (Android auto-retrieval): Firebase already grabbed the code from the SMS via
//     Google Play Services. We skip /auth/otp and sign in immediately. iOS never fires this.
//   • codeSent: SMS dispatched (or hit a TEST phone number that bypassed the network). Push /auth/otp.
//
// Test numbers configured in Firebase Console (e.g. +998 99 128 37 05 → code 123456) skip the real SMS
// path entirely — codeSent still fires; the user just types the fixed code on the OTP screen.
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
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
    final t = AppLocalizations.of(context);
    try {
      // verifyPhoneNumber is fire-and-forget — callbacks resolve asynchronously. We can't `await` the
      // SMS send completion the way we did with phone-check; instead we wait via a Completer that the
      // codeSent / verificationFailed / verificationCompleted callbacks resolve.
      final completer = _VerifyOutcome();
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: fullPhone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential cred) {
          // Android-only fast path: Play Services auto-retrieved the SMS. Sign in directly and bridge to
          // our backend without showing the OTP screen.
          completer.complete(_AutoVerified(cred));
        },
        verificationFailed: (FirebaseAuthException e) {
          completer.complete(_VerifyFailed(e));
        },
        codeSent: (String verificationId, int? resendToken) {
          // SMS dispatched (or a test number hit). The OTP screen takes over from here.
          completer.complete(_CodeSent(verificationId, resendToken));
        },
        codeAutoRetrievalTimeout: (_) { /* ignored — user can still type the code manually */ },
      );
      final outcome = await completer.future;
      if (!mounted) return;
      switch (outcome) {
        case _AutoVerified(:final credential):
          await _signInWithCredentialAndBridge(credential, fullPhone);
        case _CodeSent(:final verificationId):
          context.push('/auth/otp', extra: {
            'phone': fullPhone,
            'verificationId': verificationId,
          });
        case _VerifyFailed(:final exception):
          setState(() => _error = _humanFirebaseError(exception, t));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Auto-verification path — Firebase already proved the phone via SMS retrieval. Sign in with the
  /// credential, get the ID token, trade it for our JWT via the backend, route appropriately.
  Future<void> _signInWithCredentialAndBridge(PhoneAuthCredential cred, String fullPhone) async {
    final t = AppLocalizations.of(context);
    try {
      final userCred = await FirebaseAuth.instance.signInWithCredential(cred);
      final token = await userCred.user!.getIdToken();
      final result = await ref.read(authNotifierProvider.notifier).firebasePhoneLogin(token!);
      if (!mounted) return;
      if (result.isNew) {
        context.push('/auth/details', extra: {'phone': fullPhone});
      }
      // Existing user — AuthNotifier already flipped to AuthAuthenticated, router redirects to '/'.
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _humanFirebaseError(e, t));
    }
  }

  /// Translate FirebaseAuthException codes the user might actually hit into one-line messages. Anything
  /// not recognized falls through to the raw message so we surface SOMETHING instead of a silent failure.
  String _humanFirebaseError(FirebaseAuthException e, AppLocalizations t) {
    switch (e.code) {
      case 'invalid-phone-number': return t.phoneAuthInvalid;
      case 'too-many-requests': return 'Too many attempts — wait a few minutes';
      case 'app-not-authorized': return 'App not authorized (SHA-1 fingerprint missing in Firebase Console)';
      case 'quota-exceeded': return 'SMS quota exceeded — try again tomorrow';
      case 'invalid-app-credential': return 'App verification failed — restart the app';
      default: return e.message ?? 'Firebase error: ${e.code}';
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

/// Sealed-style record of verifyPhoneNumber outcomes. Used to bridge the multi-callback API into a single
/// awaitable point so the rest of _submit reads top-to-bottom.
sealed class _VerifyResult {}
class _AutoVerified extends _VerifyResult {
  final PhoneAuthCredential credential;
  _AutoVerified(this.credential);
}
class _CodeSent extends _VerifyResult {
  final String verificationId;
  final int? resendToken;
  _CodeSent(this.verificationId, this.resendToken);
}
class _VerifyFailed extends _VerifyResult {
  final FirebaseAuthException exception;
  _VerifyFailed(this.exception);
}

/// Tiny Completer wrapper to make the multi-callback API awaitable. We use it instead of `Completer<_VerifyResult>`
/// directly so we can gate against double-completion (which crashes Completer) — relevant because Firebase can
/// fire codeSent THEN verificationCompleted in some Android auto-retrieval scenarios.
class _VerifyOutcome {
  final _completer = _SafeCompleter<_VerifyResult>();
  Future<_VerifyResult> get future => _completer.future;
  void complete(_VerifyResult r) => _completer.complete(r);
}

class _SafeCompleter<T> {
  bool _done = false;
  final _c = Completer<T>();
  Future<T> get future => _c.future;
  void complete(T value) { if (!_done) { _done = true; _c.complete(value); } }
}


/// Same Uzbek phone formatter as before — turns raw digits into XX XXX-XX-XX as the user types.
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
