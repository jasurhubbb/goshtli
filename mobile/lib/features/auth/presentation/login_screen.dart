// Login screen — clean, hero-led, iOS-style.
//
// Visual rules: oversized title, no field borders (theme provides soft filled style), generous vertical rhythm,
// language picker tucked into a transparent app bar so it never competes with the hero.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/language_picker.dart';
import '../providers/auth_providers.dart';
import '../providers/auth_state.dart';


class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}


class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() { _email.dispose(); _password.dispose(); super.dispose(); }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authNotifierProvider.notifier).login(_email.text.trim(), _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final state = ref.watch(authNotifierProvider);
    final loading = state is AuthLoading;
    final error = state is AuthUnauthenticated ? state.error : null;

    return Scaffold(
      // Transparent AppBar holds only the language picker so the hero owns the visual weight
      appBar: AppBar(elevation: 0, backgroundColor: Colors.transparent, actions: const [LanguagePicker()]),
      body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 40),
          Text(t.signIn, style: tt.displayMedium),                     // Large title (iOS Large Title)
          const SizedBox(height: 6),
          Text(t.welcomeSubtitle, style: tt.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 40),
          TextFormField(controller: _email, keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(labelText: t.email),               // theme provides filled style
            validator: (v) => (v == null || !v.contains('@')) ? t.validateEmail : null),
          const SizedBox(height: 12),
          TextFormField(controller: _password, obscureText: true, autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(labelText: t.password),
            validator: (v) => (v == null || v.length < 8) ? t.validateMin8 : null,
            onFieldSubmitted: (_) => _submit()),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 12),
              child: Text(error, style: tt.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error))),
          const SizedBox(height: 28),
          FilledButton(onPressed: loading ? null : _submit,
              child: loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                             : Text(t.signIn)),
          const SizedBox(height: 8),
          TextButton(onPressed: loading ? null : () => context.go('/register'), child: Text(t.noAccountCta)),
        ]),
      ))),
    );
  }
}
