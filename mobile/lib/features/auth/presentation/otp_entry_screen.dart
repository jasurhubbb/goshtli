// OtpEntryScreen — second step of the v3.4 Firebase Phone Auth flow.
//
// Receives via go_router `extra`:
//   • phone           — full international format ("+998901234567"), used for the "Code sent to <phone>" line
//                       AND as the value we ultimately register the new user with on /auth/details
//   • verificationId  — Firebase's opaque session id from codeSent; combined with the user's 6 digits to build
//                       a PhoneAuthCredential we can hand to FirebaseAuth.instance.signInWithCredential
//
// On submit (auto-fires when the 6th digit is typed):
//   1. Build PhoneAuthCredential(verificationId, smsCode)
//   2. FirebaseAuth.signInWithCredential → returns a User with a verified phone claim
//   3. user.getIdToken() → signed JWT carrying that phone claim
//   4. POST /auth/firebase-phone-login/ → backend verifies + responds with either:
//        existing user → JWT pair (AuthAuthenticated) → router lands on /
//        new user      → {phone, new_user:true} → we push /auth/details for name entry
//
// Resend countdown: Firebase recommends >=60s between resends. We start a 60s timer on screen entry and
// re-arm it after a successful resend. Resending issues a NEW verificationId — we swap it in.
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/language_picker.dart';
import '../data/auth_repository.dart';
import '../providers/auth_providers.dart';
import '../providers/pending_redirect_provider.dart';


class OtpEntryScreen extends ConsumerStatefulWidget {
  final String phone;
  final String initialVerificationId;
  const OtpEntryScreen({super.key, required this.phone, required this.initialVerificationId});
  @override
  ConsumerState<OtpEntryScreen> createState() => _OtpEntryScreenState();
}


class _OtpEntryScreenState extends ConsumerState<OtpEntryScreen> {
  late String _verificationId;
  final _codeCtrl = TextEditingController();
  bool _submitting = false;
  bool _resending = false;
  String? _error;
  // Countdown drives the "Qaytadan yuborish (45s)" label and disables the resend button until 0.
  int _resendSecondsLeft = 60;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.initialVerificationId;
    _startResendCountdown();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendSecondsLeft = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_resendSecondsLeft <= 1) {
        t.cancel();
        setState(() => _resendSecondsLeft = 0);
      } else {
        setState(() => _resendSecondsLeft--);
      }
    });
  }

  Future<void> _submit(String code) async {
    if (_submitting || code.length != 6) return;
    debugPrint('[OtpEntryScreen._submit] code entered, calling Firebase signInWithCredential…');
    final t = AppLocalizations.of(context);
    // Capture the GoRouter instance BEFORE the async work begins. After the awaits resolve, the widget's
    // own context may be deactivated (Riverpod rebuild race between AuthLoading → Anonymous → Authenticated).
    // The router instance itself stays alive; calling `.go(...)` on it directly skips the context-ancestor
    // lookup that throws "Looking up a deactivated widget's ancestor is unsafe".
    final router = GoRouter.of(context);
    setState(() { _submitting = true; _error = null; });
    bool navigated = false;
    try {
      final cred = PhoneAuthProvider.credential(verificationId: _verificationId, smsCode: code);
      final userCred = await FirebaseAuth.instance.signInWithCredential(cred);
      final firebaseToken = await userCred.user!.getIdToken();
      debugPrint('[OtpEntryScreen._submit] Firebase ID token ready (${firebaseToken?.length ?? 0} chars); posting to backend');
      final result = await ref.read(authNotifierProvider.notifier).firebasePhoneLogin(firebaseToken!);
      debugPrint('[OtpEntryScreen._submit] backend bridge returned isNew=${result.isNew}');
      navigated = true;
      if (result.isNew) {
        debugPrint('[OtpEntryScreen._submit] navigating to /auth/details for name entry');
        // /auth/details preserves the pending redirect — it lives in the provider, so it survives the
        // extra step. The details screen consumes it after the final phoneRegister call.
        router.go('/auth/details', extra: {'phone': widget.phone});
      } else {
        // Existing user — if the buyer started login from the checkout flow, hand them back to the
        // delivery page (or wherever the pending-redirect provider was stashed). Otherwise go home.
        final next = ref.read(pendingRedirectProvider.notifier).take() ?? '/';
        debugPrint('[OtpEntryScreen._submit] navigating to $next (existing user)');
        router.go(next);
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('[OtpEntryScreen._submit] FirebaseAuthException ${e.code}: ${e.message}');
      _safeSetState(() => _error = _humanFirebaseError(e, t));
    } on AuthException catch (e) {
      debugPrint('[OtpEntryScreen._submit] AuthException (from backend): ${e.message}');
      _safeSetState(() => _error = e.message);
    } catch (e, st) {
      // Generic catch for DioException (5xx, network down) + any other unexpected error. Dumping raw
      // `e.toString()` to the UI surfaces stack-trace-shaped errors to end users ("DioException [bad
      // response]: This exception was thrown because the response has a status code of 503..."). Map to
      // a friendly localized string instead; the full diagnostic stays in debugPrint for our logs.
      debugPrint('[OtpEntryScreen._submit] UNEXPECTED $e\n$st');
      _safeSetState(() => _error = _humanUnexpectedError(e, t));
    } finally {
      if (!navigated) _safeSetState(() => _submitting = false);
    }
  }

  /// setState wrapper that survives the "mounted == true but element is defunct" race window. The OTP
  /// flow spawns long-running awaits (Firebase signInWithCredential + backend POST, up to 10s each);
  /// during those windows the user might navigate away, popping the screen. `mounted` returns true until
  /// `dispose()` runs, but the Element's `_lifecycleState` can already be `defunct` — which makes
  /// `setState` assert. We silently swallow that one assertion; everything else still throws.
  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    try {
      setState(fn);
    } on AssertionError catch (e) {
      // Only swallow the defunct-element assertion. Anything else (e.g. setState called outside build
      // when the widget really IS alive) should still surface so we notice the real bugs.
      if (!e.toString().contains('_lifecycleState')) rethrow;
      debugPrint('[OtpEntryScreen._safeSetState] swallowed defunct-element setState (widget being disposed)');
    }
  }

  Future<void> _resend() async {
    if (_resending || _resendSecondsLeft > 0) return;
    final t = AppLocalizations.of(context);
    setState(() { _resending = true; _error = null; });
    final completer = Completer<String?>();
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: widget.phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (_) {/* Auto-retrieved — we don't navigate here; let user manually enter if they prefer */},
        verificationFailed: (e) { if (!completer.isCompleted) completer.completeError(e); },
        codeSent: (vid, _) { if (!completer.isCompleted) completer.complete(vid); },
        codeAutoRetrievalTimeout: (_) { /* ignore */ },
      );
      final newVid = await completer.future;
      if (newVid != null && mounted) {
        setState(() { _verificationId = newVid; _codeCtrl.clear(); });
        _startResendCountdown();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _humanFirebaseError(e, t));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  String _humanFirebaseError(FirebaseAuthException e, AppLocalizations t) {
    switch (e.code) {
      case 'invalid-verification-code': return t.otpInvalidCode;
      case 'session-expired': return t.otpExpired;
      case 'too-many-requests': return 'Too many attempts — wait a few minutes';
      default: return e.message ?? 'Firebase error: ${e.code}';
    }
  }

  /// Map an arbitrary thrown error to a user-friendly localized message. We branch on the toString()
  /// prefix because Dio's exception class isn't statically imported here and we don't want a new
  /// `package:dio` dependency in the auth UI just for one `is DioException` check.
  String _humanUnexpectedError(Object e, AppLocalizations t) {
    final s = e.toString();
    if (s.contains('5') && s.contains('status code') && s.contains('50')) {
      // 5xx — server-side. Most common in early prod: Firebase Admin SDK not configured on the backend,
      // missing env vars, or a deploy that didn't run migrations.
      return t.authServerUnavailable;
    }
    if (s.contains('SocketException') || s.contains('Network is unreachable')
        || s.contains('Connection refused') || s.contains('Failed host lookup')) {
      return t.authNetworkError;
    }
    if (s.contains('TimeoutException') || s.contains('connection timeout')) {
      return t.authNetworkTimeout;
    }
    return t.authUnexpectedError;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(elevation: 0, backgroundColor: Colors.transparent, actions: const [LanguagePicker()]),
      body: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(height: 24),
            Text(t.otpTitle, style: tt.displayMedium),
            const SizedBox(height: 8),
            // "SMS code sent to +998 90 123-45-67" — uses the same display formatting as PhoneEntryScreen
            Text(t.otpSentTo(_pretty(widget.phone)),
                style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 32),
            // 6-box PIN field — handles paste, autofill (Android SMS retriever), and per-box visuals natively.
            PinCodeTextField(
              appContext: context,
              length: 6,
              controller: _codeCtrl,
              autoFocus: true,
              keyboardType: TextInputType.number,
              animationType: AnimationType.fade,
              cursorColor: cs.primary,
              textStyle: tt.headlineSmall,
              pinTheme: PinTheme(
                shape: PinCodeFieldShape.box,
                borderRadius: BorderRadius.circular(12),
                fieldHeight: 56,
                fieldWidth: 44,
                activeColor: cs.primary,
                selectedColor: cs.primary,
                inactiveColor: cs.outlineVariant,
                activeFillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                selectedFillColor: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                inactiveFillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              ),
              enableActiveFill: true,
              onChanged: (_) { if (_error != null) setState(() => _error = null); },
              onCompleted: _submit,                                            // auto-submit when 6 digits typed
            ),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 8),
                child: Center(child: Text(_error!,
                    style: tt.bodyMedium?.copyWith(color: cs.error)))),
            const SizedBox(height: 16),
            // Resend row: shows countdown when locked, becomes a tappable button after 60s
            Center(child: _resendSecondsLeft > 0
                ? Text(t.otpResendIn(_resendSecondsLeft),
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant))
                : TextButton(onPressed: _resending ? null : _resend,
                    child: _resending
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(t.otpResend))),
          ]),
        )),
        Padding(padding: EdgeInsets.fromLTRB(24, 8, 24,
            MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 24),
          child: SizedBox(height: 56, child: FilledButton(
            // Manual submit fallback in case onCompleted didn't fire (rare — but the button is the natural
            // anchor users look at after typing, so we keep it visible + enabled when 6 digits are present).
            onPressed: (_codeCtrl.text.length == 6 && !_submitting) ? () => _submit(_codeCtrl.text) : null,
            style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            child: _submitting
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : Text(t.phoneAuthContinue, style: tt.titleMedium?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          )),
        ),
      ])),
    );
  }

  /// "+998901234567" → "+998 90 123-45-67" so the user sees the same format they entered on the previous
  /// screen. Mirrors _UzPhoneFormatter._format from phone_entry_screen.dart.
  String _pretty(String e164) {
    if (!e164.startsWith('+998')) return e164;
    final d = e164.substring(4);
    if (d.length < 9) return e164;
    return '+998 ${d.substring(0, 2)} ${d.substring(2, 5)}-${d.substring(5, 7)}-${d.substring(7, 9)}';
  }
}
