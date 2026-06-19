import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';

import '../../core/auth/partner_auth_notifier.dart';
import '../../core/network/providers.dart';
import '../../l10n/app_localizations.dart';


/// Edit profile sheet — name + phone-call availability (phone_visible).
///
/// Routes to the role-specific endpoint on save:
///   QASSOB   -> PATCH /qassobs/me/
///   SUPPLIER -> PATCH /suppliers/me/
///
/// `full_name` also writes back to /auth/me/ so the dashboard greeting updates immediately.
Future<bool> showEditProfileSheet(BuildContext context, {
  required String currentName,
  required bool currentPhoneVisible,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EditProfileSheet(
      initialName: currentName,
      initialPhoneVisible: currentPhoneVisible,
    ),
  );
  return result ?? false;
}


class _EditProfileSheet extends ConsumerStatefulWidget {
  final String initialName;
  final bool initialPhoneVisible;
  const _EditProfileSheet({required this.initialName, required this.initialPhoneVisible});
  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}


class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _name;
  late bool _phoneVisible;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName);
    _phoneVisible = widget.initialPhoneVisible;
  }

  @override
  void dispose() { _name.dispose(); super.dispose(); }

  Future<void> _save() async {
    setState(() { _submitting = true; _error = null; });
    HapticFeedback.selectionClick();
    final auth = ref.read(partnerAuthProvider);
    if (auth is! AuthAuthenticated) return;
    final api = ref.read(apiClientProvider);
    final fullName = _name.text.trim();
    try {
      // 1) Update User.full_name via /auth/me/ — drives the dashboard greeting.
      await api.dio.patch('/auth/me/', data: {'full_name': fullName});
      // 2) Update role-specific profile (name + phone_visible).
      if (auth.user.isQassob) {
        await api.dio.patch('/qassobs/me/', data: {
          'full_name': fullName,
          'phone_visible': _phoneVisible,
        });
      } else if (auth.user.isSupplier) {
        await api.dio.patch('/suppliers/me/', data: {
          'full_name': fullName,
          'phone_visible': _phoneVisible,
        });
      }
      // 3) Refresh the AuthState user so the greeting updates immediately without an app restart.
      final me = await api.dio.get('/auth/me/');
      ref.read(partnerAuthProvider.notifier)
          .setAuthenticated(User.fromJson(me.data as Map<String, dynamic>));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() { _submitting = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        child: SafeArea(top: false, child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: Container(width: 40, height: 4,
                margin: const EdgeInsets.only(top: 6, bottom: 16),
                decoration: BoxDecoration(color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2)))),
            Text(t.profileEditTitle,
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),
            TextField(controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: t.profileEditFullName)),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              value: _phoneVisible,
              onChanged: (v) => setState(() => _phoneVisible = v),
              title: Text(t.profileEditCallsAvailable,
                  style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
              subtitle: Text(t.profileEditCallsAvailableHint,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              contentPadding: EdgeInsets.zero),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: cs.error))),
            const SizedBox(height: 18),
            FilledButton(onPressed: _submitting ? null : _save,
              child: _submitting
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(
                      strokeWidth: 2.4, color: Colors.white))
                  : Text(t.save)),
          ]))),
      ),
    );
  }
}
