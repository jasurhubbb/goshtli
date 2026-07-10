// OtpEntryScreen — second step of the v3.9.16 Telegram phone-verification flow (formerly the Firebase OTP
// screen). Named "otp" for route stability; it is now a Telegram code-entry screen.
//
// Receives via go_router `extra`:
//   • phone        — "+998901234567", shown to the user + registered on /auth/details for new users
//   • sessionToken — the verification session opened by /auth/telegram/start/; paired with the 6 digits on verify
//   • botUrl       — the https://t.me/<bot>?start=<token> deep link the "Botga o'tish" button opens
//
// Flow: user taps "Botga o'tish" → bot opens → shares contact → bot sends a 6-digit code → user returns and
// types it → POST /auth/telegram/verify/ → existing user lands on '/', new user pushes /auth/details.
//
// Resend re-opens a fresh session via /auth/telegram/start/ (the old one is swept server-side), swapping in the
// new session token + bot URL.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/language_picker.dart';
import '../data/auth_repository.dart';
import '../providers/auth_providers.dart';
import '../providers/pending_redirect_provider.dart';


class OtpEntryScreen extends ConsumerStatefulWidget {
  final String phone;
  final String sessionToken;
  final String botUrl;
  const OtpEntryScreen({super.key, required this.phone, required this.sessionToken, required this.botUrl});
  @override
  ConsumerState<OtpEntryScreen> createState() => _OtpEntryScreenState();
}


class _OtpEntryScreenState extends ConsumerState<OtpEntryScreen> {
  late String _sessionToken;
  late String _botUrl;
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
    _sessionToken = widget.sessionToken;
    _botUrl = widget.botUrl;
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

  /// Opens the bot via the deep link. LaunchMode.externalApplication forces the Telegram app (not an
  /// in-app webview) so the ?start= payload triggers the bot's /start.
  Future<void> _openBot() async {
    final uri = Uri.parse(_botUrl);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) setState(() => _error = "Telegram ochilmadi. Telegram o'rnatilganini tekshiring.");
    } catch (_) {
      if (mounted) setState(() => _error = "Telegram ochilmadi. Telegram o'rnatilganini tekshiring.");
    }
  }

  Future<void> _submit(String code) async {
    if (_submitting || code.length != 6) return;
    // Capture the GoRouter BEFORE the async work — after awaits the widget's context may be deactivated
    // during the Riverpod rebuild race (AuthLoading → Anonymous → Authenticated).
    final router = GoRouter.of(context);
    final t = AppLocalizations.of(context);
    setState(() { _submitting = true; _error = null; });
    bool navigated = false;
    try {
      final result = await ref.read(authNotifierProvider.notifier).telegramVerify(_sessionToken, code);
      navigated = true;
      if (result.isNew) {
        // /auth/details preserves the pending redirect (it lives in the provider), consumed after phoneRegister.
        router.go('/auth/details', extra: {'phone': widget.phone});
      } else {
        // Existing user — hand back to the checkout flow if that's where login started, else home.
        final next = ref.read(pendingRedirectProvider.notifier).take() ?? '/';
        router.go(next);
      }
    } on AuthException catch (e) {
      _safeSetState(() => _error = e.message);
    } catch (e) {
      _safeSetState(() => _error = _humanUnexpectedError(e, t));
    } finally {
      if (!navigated) _safeSetState(() => _submitting = false);
    }
  }

  /// setState wrapper that survives the "mounted == true but element is defunct" race during the long
  /// verify await if the user navigates away mid-request.
  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    try {
      setState(fn);
    } on AssertionError catch (e) {
      if (!e.toString().contains('_lifecycleState')) rethrow;
    }
  }

  Future<void> _resend() async {
    if (_resending || _resendSecondsLeft > 0) return;
    setState(() { _resending = true; _error = null; });
    try {
      // Re-open a fresh session (the old one is swept server-side when a new one is created for this phone).
      final started = await ref.read(authRepositoryProvider).telegramStart(widget.phone);
      if (mounted) {
        setState(() { _sessionToken = started.sessionToken; _botUrl = started.botUrl; _codeCtrl.clear(); });
        _startResendCountdown();
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = _humanUnexpectedError(e, AppLocalizations.of(context)));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  /// Map an arbitrary thrown error to a user-friendly localized message. Branches on toString() prefix so we
  /// don't need a `package:dio` import in the auth UI just for one `is DioException` check.
  String _humanUnexpectedError(Object e, AppLocalizations t) {
    final s = e.toString();
    if (s.contains('5') && s.contains('status code') && s.contains('50')) return t.authServerUnavailable;
    if (s.contains('SocketException') || s.contains('Network is unreachable')
        || s.contains('Connection refused') || s.contains('Failed host lookup')) {
      return t.authNetworkError;
    }
    if (s.contains('TimeoutException') || s.contains('connection timeout')) return t.authNetworkTimeout;
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
            // Telegram-specific instruction (replaces "SMS sent to X"): go to the bot, share the number, get a code.
            Text("Telegram botiga o'ting, raqamingizni yuboring va olgan kodni shu yerga kiriting.\n${_pretty(widget.phone)}",
                style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 20),
            // "Botga o'tish" — the primary call to action. Opens the bot with the ?start= payload.
            SizedBox(height: 52, child: FilledButton.tonalIcon(
              onPressed: _openBot,
              icon: const Icon(Icons.send_rounded),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF229ED9).withValues(alpha: 0.14),
                  foregroundColor: const Color(0xFF0B7EBB),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              label: const Text("Botga o'tish", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)))),
            const SizedBox(height: 24),
            // 6-box code field.
            PinCodeTextField(
              appContext: context,
              length: 6,
              controller: _codeCtrl,
              autoFocus: false,
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
            // Resend row: countdown when locked, tappable after 60s (re-opens a fresh session).
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

  /// "+998901234567" → "+998 90 123-45-67" so the user sees the same format they typed.
  String _pretty(String e164) {
    if (!e164.startsWith('+998')) return e164;
    final d = e164.substring(4);
    if (d.length < 9) return e164;
    return '+998 ${d.substring(0, 2)} ${d.substring(2, 5)}-${d.substring(5, 7)}-${d.substring(7, 9)}';
  }
}
