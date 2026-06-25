import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../../core/auth/partner_auth_notifier.dart';
import '../../core/network/providers.dart';
import '../../l10n/app_localizations.dart';

/// OTP entry. Reads `phone` + `verificationId` from extra. Builds Firebase PhoneAuthCredential, signs
/// in, fetches the Firebase ID token, exchanges it for backend JWT via FirebasePhoneBridge.
///
/// New user → push /onboarding (wizard reads role from roleDraftProvider).
/// Existing user → go to /home.
class OtpEntryScreen extends ConsumerStatefulWidget {
  final String phone;
  final String verificationId;
  const OtpEntryScreen({super.key, required this.phone, required this.verificationId});
  @override
  ConsumerState<OtpEntryScreen> createState() => _OtpEntryScreenState();
}


class _OtpEntryScreenState extends ConsumerState<OtpEntryScreen> {
  String _code = '';
  bool _submitting = false;
  String? _error;
  int _resendSec = 60;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _resendSec = (_resendSec - 1).clamp(0, 60));
    });
  }

  @override
  void dispose() { _resendTimer?.cancel(); super.dispose(); }

  Future<void> _submit() async {
    if (_code.length < 6) return;
    setState(() { _submitting = true; _error = null; });
    HapticFeedback.selectionClick();
    final router = GoRouter.of(context);
    try {
      final cred = PhoneAuthProvider.credential(
          verificationId: widget.verificationId, smsCode: _code);
      final userCred = await FirebaseAuth.instance.signInWithCredential(cred);
      final idToken = await userCred.user?.getIdToken();
      if (idToken == null) throw Exception('Firebase returned no ID token');
      final res = await ref.read(firebaseBridgeProvider).exchange(idToken);
      if (res.isNew) {
        if (mounted) router.go('/onboarding', extra: {'phone': res.phone});
      } else {
        ref.read(partnerAuthProvider.notifier).setAuthenticated(res.user!);
        if (mounted) router.go('/home');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() {
        // Distinguish the two common failure modes Firebase rolls up under different codes. The
        // previous behavior mapped 'invalid-verification-code' to a combined "noto'g'ri yoki
        // muddati o'tgan" string which confused users — they'd see "muddati o'tgan" (expired)
        // after entering the wrong digits and assume their code had timed out.
        switch (e.code) {
          case 'invalid-verification-code':
            _error = "Kod noto'g'ri — qaytadan urinib ko'ring";
          case 'code-expired':
          case 'session-expired':
            _error = "Kod muddati o'tgan — qayta kod yuboring";
          default:
            _error = e.message ?? 'Firebase error: ${e.code}';
        }
        _submitting = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _submitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop())),
      body: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(t.otpTitle, style: tt.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(t.otpSubtitle(widget.phone),
              style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 28),
          PinCodeTextField(
            appContext: context,
            length: 6,
            keyboardType: TextInputType.number,
            autoFocus: true,
            onChanged: (v) { setState(() { _code = v; if (_error != null) _error = null; }); },
            onCompleted: (_) => _submit(),
            pinTheme: PinTheme(
              shape: PinCodeFieldShape.box,
              borderRadius: BorderRadius.circular(12),
              fieldWidth: 44, fieldHeight: 56,
              activeColor: cs.primary,
              selectedColor: cs.primary,
              inactiveColor: cs.outlineVariant,
              activeFillColor: Colors.white,
              selectedFillColor: Colors.white,
              inactiveFillColor: cs.surfaceContainerLowest,
            ),
            enableActiveFill: true,
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 6),
              child: Text(_error!, style: TextStyle(color: cs.error))),
          const SizedBox(height: 12),
          Center(child: Text(t.otpResend(_resendSec),
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant))),
          const Spacer(),
          FilledButton(onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : Text(t.confirm)),
        ]))));
  }
}
