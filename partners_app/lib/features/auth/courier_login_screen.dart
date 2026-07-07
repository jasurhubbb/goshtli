import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';

import '../../core/auth/partner_auth_notifier.dart';
import '../../core/network/providers.dart';
import '../../l10n/app_localizations.dart';


/// Courier email + password login.
///
/// v3.9.15 — couriers don't self-register; ops provisions them via `manage.py provision_courier`
/// (or the /couriers/admin/provision/ endpoint from the admin UI). This screen just calls
/// /auth/login/ with email + password, persists the returned {access, refresh}, then dispatches
/// into the courier shell.
///
/// Distinct from the qassob/supplier phone-OTP flow: no roleDraftProvider dependency, no wizard,
/// no Firebase. It's a plain form because the driver already has credentials in hand when they
/// open the app for the first time.
class CourierLoginScreen extends ConsumerStatefulWidget {
  const CourierLoginScreen({super.key});
  @override
  ConsumerState<CourierLoginScreen> createState() => _CourierLoginScreenState();
}


class _CourierLoginScreenState extends ConsumerState<CourierLoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _submitting = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = "Email va parolni to'ldiring");
      return;
    }
    setState(() { _submitting = true; _error = null; });
    HapticFeedback.selectionClick();
    try {
      final api = ref.read(apiClientProvider);
      final tokens = ref.read(tokenStorageProvider);
      final r = await api.dio.post('/auth/login/',
          data: {'email': email, 'password': password});
      if (r.statusCode != 200) {
        setState(() {
          _submitting = false;
          _error = _extractDetail(r.data) ?? 'HTTP ${r.statusCode}';
        });
        return;
      }
      final data = r.data as Map<String, dynamic>;
      await tokens.writeBoth(
          access: data['access'] as String,
          refresh: data['refresh'] as String);
      final me = await api.dio.get('/auth/me/');
      final user = User.fromJson(me.data as Map<String, dynamic>);
      ref.read(partnerAuthProvider.notifier).setAuthenticated(user);
      if (mounted) context.go('/home');
    } on DioException catch (e) {
      setState(() {
        _submitting = false;
        _error = _extractDetail(e.response?.data) ?? e.message ?? 'Tarmoq xatosi';
      });
    } catch (e) {
      setState(() { _submitting = false; _error = e.toString(); });
    }
  }

  String? _extractDetail(dynamic data) {
    if (data is! Map) return null;
    if (data['detail'] is String) return data['detail'] as String;
    // simplejwt's default 401 body is {"detail": "No active account found..."} but on 400 it
    // returns {field: [msg]} pairs; flatten so the courier sees why login failed.
    final parts = <String>[];
    data.forEach((k, v) {
      if (v is List && v.isNotEmpty) parts.add('$k: ${v.first}');
      else if (v is String) parts.add('$k: $v');
    });
    return parts.isEmpty ? null : parts.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop())),
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Hero icon
          Center(child: Container(width: 96, height: 96,
            decoration: const BoxDecoration(color: Color(0x1A0D47A1),
                shape: BoxShape.circle),
            child: const Icon(Icons.delivery_dining_rounded, size: 48,
                color: Color(0xFF0D47A1)))),
          const SizedBox(height: 24),
          Text("Kuryer sifatida kirish",
              style: tt.displaySmall?.copyWith(fontWeight: FontWeight.w800,
                  letterSpacing: -0.5)),
          const SizedBox(height: 6),
          Text("Admin bergan email va parol bilan kiring",
              style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 28),
          TextField(controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textCapitalization: TextCapitalization.none,
            enableSuggestions: false,
            autocorrect: false,
            decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
                hintText: 'kuryer@example.uz')),
          const SizedBox(height: 14),
          TextField(controller: _passwordCtrl,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: 'Parol',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure))),
            onSubmitted: (_) => _submit()),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: TextStyle(color: cs.error))),
          const SizedBox(height: 22),
          FilledButton(onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
            child: _submitting
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: Colors.white))
                : const Text("Kirish",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          const SizedBox(height: 12),
          Center(child: TextButton(onPressed: () => context.go('/role-pick'),
              child: Text("Boshqa rolni tanlash",
                  style: TextStyle(color: cs.onSurfaceVariant)))),
        ]))));
  }
}
