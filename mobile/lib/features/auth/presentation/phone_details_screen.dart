// PhoneDetailsScreen — second (and last) step of the unified phone signup flow.
//
// Reached only when /auth/phone-check/ said the phone was new. We collect name (required) and an optional
// business_name, then call phoneRegister to atomically create the account and log the user in. On success the
// router redirect lands the user on '/' — there's no extra "welcome" page in v3.2.
//
// Why two screens instead of one form: per the v3.2 spec, "each step in its own page" — gives the buyer a
// distraction-free name field that doesn't compete with the phone capture.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/language_picker.dart';
import '../providers/auth_providers.dart';
import '../providers/auth_state.dart';


class PhoneDetailsScreen extends ConsumerStatefulWidget {
  /// Phone in full international format (+998XXXXXXXXX), passed from PhoneEntryScreen via go_router extra.
  final String phone;
  const PhoneDetailsScreen({super.key, required this.phone});

  @override
  ConsumerState<PhoneDetailsScreen> createState() => _PhoneDetailsScreenState();
}


class _PhoneDetailsScreenState extends ConsumerState<PhoneDetailsScreen> {
  final _name = TextEditingController();
  final _business = TextEditingController();
  // Watch both controllers via setState so the CTA enables only once name has at least 2 chars.
  String _nameVal = '';

  @override
  void initState() {
    super.initState();
    _name.addListener(() { if (_nameVal != _name.text) setState(() => _nameVal = _name.text); });
  }

  @override
  void dispose() { _name.dispose(); _business.dispose(); super.dispose(); }

  bool get _canSubmit => _nameVal.trim().length >= 2;        // server min_length=1, but require >=2 for typo guard

  Future<void> _submit() async {
    if (!_canSubmit) return;
    await ref.read(authNotifierProvider.notifier).phoneRegister(
      phone: widget.phone,
      fullName: _name.text.trim(),
      businessName: _business.text.trim(),
    );
    // No manual navigation — router redirect flips to '/' once AuthAuthenticated lands.
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final state = ref.watch(authNotifierProvider);
    final loading = state is AuthLoading;
    final error = state is AuthUnauthenticated ? state.error : null;

    return Scaffold(
      // Back arrow lets the user correct a wrong phone number; language picker stays on the right.
      appBar: AppBar(elevation: 0, backgroundColor: Colors.transparent, actions: const [LanguagePicker()]),
      body: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 32),
          Text(t.phoneDetailsTitle, style: tt.displayMedium),
          const SizedBox(height: 8),
          Text(t.phoneDetailsSubtitle, style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 40),
          // Name — required, big input matching the phone screen styling for visual consistency.
          TextField(
            controller: _name, autofocus: true,
            keyboardType: TextInputType.name, textCapitalization: TextCapitalization.words,
            style: tt.titleLarge,
            decoration: InputDecoration(labelText: t.phoneDetailsNameLabel),
            onSubmitted: (_) { if (_canSubmit) _submit(); },
          ),
          const SizedBox(height: 16),
          // Business name — optional; smaller weight, but uses the same input style as the rest of the app.
          TextField(
            controller: _business,
            keyboardType: TextInputType.text, textCapitalization: TextCapitalization.words,
            style: tt.titleMedium,
            decoration: InputDecoration(labelText: t.phoneDetailsBusinessLabel),
            onSubmitted: (_) { if (_canSubmit) _submit(); },
          ),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 12),
              child: Text(error, style: tt.bodyMedium?.copyWith(color: cs.error))),
          const Spacer(),
          SizedBox(height: 56, child: FilledButton(
            onPressed: (_canSubmit && !loading) ? _submit : null,
            style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            child: loading
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : Text(t.phoneDetailsCta, style: tt.titleMedium?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          )),
          const SizedBox(height: 8),
        ]),
      )),
    );
  }
}
