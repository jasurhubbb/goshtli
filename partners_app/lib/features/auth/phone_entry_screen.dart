import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';

/// Phone entry screen. User types +998 ... → tap "Kod yuborish" → FirebaseAuth.verifyPhoneNumber
/// dispatches the SMS → navigate to /auth/otp.
class PhoneEntryScreen extends ConsumerStatefulWidget {
  const PhoneEntryScreen({super.key});
  @override
  ConsumerState<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}


class _PhoneEntryScreenState extends ConsumerState<PhoneEntryScreen> {
  final _ctrl = TextEditingController(text: '+998');
  bool _submitting = false;
  String? _error;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _send() async {
    final t = AppLocalizations.of(context);
    final phone = _ctrl.text.trim();
    if (!RegExp(r'^\+\d{9,15}$').hasMatch(phone)) {
      setState(() => _error = t.phoneEntryError); return;
    }
    setState(() { _submitting = true; _error = null; });
    HapticFeedback.selectionClick();
    final router = GoRouter.of(context);
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (cred) async {
          // Auto-resolved on some Android devices — push the user to OTP with the credential pre-applied.
          router.push('/auth/otp', extra: {'phone': phone, 'verificationId': '', 'auto': true});
        },
        verificationFailed: (e) {
          if (mounted) setState(() { _error = e.message ?? 'Firebase error: ${e.code}'; _submitting = false; });
        },
        codeSent: (verificationId, resendToken) {
          if (mounted) {
            setState(() => _submitting = false);
            router.push('/auth/otp', extra: {'phone': phone, 'verificationId': verificationId});
          }
        },
        codeAutoRetrievalTimeout: (_) {},
      );
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
          Text(t.phoneEntryTitle,
              style: tt.displaySmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 24),
          TextField(
            controller: _ctrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[+\d]')),
                              LengthLimitingTextInputFormatter(16)],
            style: tt.headlineSmall,
            decoration: InputDecoration(hintText: t.phoneEntryHint),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: TextStyle(color: cs.error))),
          const Spacer(),
          FilledButton(onPressed: _submitting ? null : _send,
            child: _submitting
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : Text(t.phoneEntrySendCode)),
        ]))));
  }
}
