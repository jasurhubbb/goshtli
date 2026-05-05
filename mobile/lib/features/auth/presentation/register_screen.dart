// Register screen — same Apple-style hero treatment as login. Form fields inherit theme's filled style.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/language_picker.dart';
import '../providers/auth_providers.dart';
import '../providers/auth_state.dart';


class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}


class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  UserRole _role = UserRole.buyer;

  @override
  void dispose() {
    for (final c in [_fullName, _email, _phone, _password, _confirm]) { c.dispose(); }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authNotifierProvider.notifier).register(
      email: _email.text.trim(), fullName: _fullName.text.trim(),
      password: _password.text, phone: _phone.text.trim(), role: _role);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final state = ref.watch(authNotifierProvider);
    final loading = state is AuthLoading;
    final error = state is AuthUnauthenticated ? state.error : null;

    return Scaffold(
      appBar: AppBar(elevation: 0, backgroundColor: Colors.transparent, actions: const [LanguagePicker()]),
      body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 8),
          Text(t.createAccount, style: tt.displayMedium),
          const SizedBox(height: 28),
          TextFormField(controller: _fullName, autofillHints: const [AutofillHints.name],
            decoration: InputDecoration(labelText: t.fullName),
            validator: (v) => (v == null || v.trim().length < 2) ? t.validateName : null),
          const SizedBox(height: 12),
          TextFormField(controller: _email, keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(labelText: t.email),
            validator: (v) => (v == null || !v.contains('@')) ? t.validateEmail : null),
          const SizedBox(height: 12),
          TextFormField(controller: _phone, keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            decoration: InputDecoration(labelText: t.phone)),
          const SizedBox(height: 12),
          TextFormField(controller: _password, obscureText: true, autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(labelText: t.passwordMin8),
            validator: (v) => (v == null || v.length < 8) ? t.validateMin8 : null),
          const SizedBox(height: 12),
          TextFormField(controller: _confirm, obscureText: true,
            decoration: InputDecoration(labelText: t.confirmPassword),
            validator: (v) => v != _password.text ? t.validatePasswordMatch : null),
          const SizedBox(height: 20),
          // Role picker — full-width segmented control like iOS
          SizedBox(width: double.infinity, child: SegmentedButton<UserRole>(
            segments: [
              ButtonSegment(value: UserRole.buyer, label: Text(t.roleBuyer), icon: const Icon(Icons.shopping_cart_outlined)),
              ButtonSegment(value: UserRole.supplier, label: Text(t.roleSupplier), icon: const Icon(Icons.storefront_outlined)),
            ],
            selected: {_role},
            onSelectionChanged: loading ? null : (s) => setState(() => _role = s.first))),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 12),
              child: Text(error, style: tt.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error))),
          const SizedBox(height: 28),
          FilledButton(onPressed: loading ? null : _submit,
              child: loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                             : Text(t.createAccount)),
          const SizedBox(height: 8),
          TextButton(onPressed: loading ? null : () => context.go('/login'), child: Text(t.haveAccountCta)),
        ]),
      ))),
    );
  }
}
