import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';

import '../../core/auth/partner_auth_notifier.dart';
import '../../core/auth/role_draft_provider.dart';
import '../../core/network/providers.dart';


/// v3.9.16 — unified partner login. Supplier, qassob AND courier all sign in here with the phone + password
/// ops issued them (see backend provision_supplier / provision_qassob / provision_courier). Replaces the
/// Firebase phone-OTP signup + the separate courier email login — partners no longer self-register.
///
/// After login we route by role + profile completeness:
///   • courier                    → /home (courier shell)
///   • supplier/qassob, no profile→ /onboarding (the setup wizard fills business details)
///   • supplier/qassob, complete  → /home (partner shell)
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}


class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const String _dialCode = '+998';
  static const int _localDigits = 9;
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _submitting = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String get _rawDigits => _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
  bool get _valid => _rawDigits.length == _localDigits && _passwordCtrl.text.isNotEmpty;

  Future<void> _submit() async {
    if (!_valid || _submitting) return;
    final phone = '$_dialCode$_rawDigits';
    final router = GoRouter.of(context);
    setState(() { _submitting = true; _error = null; });
    HapticFeedback.selectionClick();
    try {
      final user = await ref.read(authBridgeProvider)
          .phonePasswordLogin(phone: phone, password: _passwordCtrl.text);
      ref.read(partnerAuthProvider.notifier).setAuthenticated(user);
      final dest = await _postLoginRoute(user);
      if (mounted) router.go(dest);
    } on ApiException catch (e) {
      if (mounted) setState(() { _submitting = false; _error = e.message; });
    } catch (e) {
      if (mounted) setState(() { _submitting = false; _error = e.toString(); });
    }
  }

  /// Decide where the partner lands. Couriers go straight to their shell. For supplier/qassob we peek at
  /// their profile: if the wizard-collected `animals_supported` is still empty, the account was just
  /// provisioned → run the setup wizard; otherwise go home. On any profile-fetch error we default to /home
  /// (never block a valid login on a profile hiccup).
  Future<String> _postLoginRoute(User user) async {
    if (user.role == UserRole.courier) return '/home';
    if (user.role == UserRole.supplier || user.role == UserRole.qassob) {
      await ref.read(roleDraftProvider.notifier).set(user.role);
      final path = user.role == UserRole.supplier ? '/suppliers/me/' : '/qassobs/me/';
      try {
        final r = await ref.read(apiClientProvider).dio.get(path);
        final animals = (r.data is Map ? r.data['animals_supported'] : null);
        final incomplete = animals is! List || animals.isEmpty;
        return incomplete ? '/onboarding' : '/home';
      } catch (_) {
        return '/home';
      }
    }
    return '/home';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 12),
          Center(child: Container(width: 96, height: 96,
            decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle),
            child: Icon(Icons.storefront_rounded, size: 48, color: cs.primary))),
          const SizedBox(height: 24),
          Text("Hamkor sifatida kirish",
              textAlign: TextAlign.center,
              style: tt.displaySmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          const SizedBox(height: 6),
          Text("Biz bergan telefon raqami va parol bilan kiring",
              textAlign: TextAlign.center,
              style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 28),
          // Phone field with a fixed +998 prefix (matches the buyer app's entry look).
          Container(
            decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(children: [
              Text(_dialCode, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(width: 10),
              Container(width: 1, height: 24, color: cs.outlineVariant),
              const SizedBox(width: 10),
              Expanded(child: TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [_UzPhoneFormatter()],
                style: tt.titleMedium,
                onChanged: (_) { if (_error != null) setState(() => _error = null); },
                decoration: const InputDecoration(
                    border: InputBorder.none, isCollapsed: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 18),
                    hintText: '90 123-45-67'),
              )),
            ]),
          ),
          const SizedBox(height: 14),
          TextField(controller: _passwordCtrl,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.password],
            onChanged: (_) { if (_error != null) setState(() => _error = null); },
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: 'Parol',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure)))),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: TextStyle(color: cs.error))),
          const SizedBox(height: 24),
          SizedBox(height: 54, child: FilledButton(
            onPressed: (_valid && !_submitting) ? _submit : null,
            style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: _submitting
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: Colors.white))
                : const Text("Kirish", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)))),
          const SizedBox(height: 16),
          Text("Hisobingiz yo'qmi? Hamkor bo'lish uchun biz bilan bog'laning.",
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ]))),
    );
  }
}


/// Uzbek phone formatter — XX XXX-XX-XX as the user types (mirrors the buyer app).
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
