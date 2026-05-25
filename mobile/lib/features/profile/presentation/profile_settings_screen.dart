// ProfileSettingsScreen — buyer's personal details editor (v3.3).
//
// Reached by tapping the account card on the Profile tab. Mirrors the Uzum-style settings sheet:
//   Familiya / Ism / Otasining ismi / Tug'ilgan kun (DatePicker) / Jins (segmented) / Telefon raqami (read-only)
//   then Chiqish (Logout) and Akkauntni o'chirish (red destructive)
//
// Phone is read-only here — changing the login phone needs the v3.2 OTP flow we haven't built yet. Email is
// intentionally hidden from this UI per spec; the field still exists on the backend for staff/admin paths.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/models/user.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/providers/auth_state.dart';


class ProfileSettingsScreen extends ConsumerStatefulWidget {
  const ProfileSettingsScreen({super.key});
  @override
  ConsumerState<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}


class _ProfileSettingsScreenState extends ConsumerState<ProfileSettingsScreen> {
  final _last = TextEditingController();
  final _first = TextEditingController();
  final _patronymic = TextEditingController();
  DateTime? _dob;
  UserGender? _gender;
  bool _hydrated = false;                                          // one-shot hydrate when AuthAuthenticated lands
  bool _saving = false;
  String? _err;
  // Debounced auto-save: every field change schedules a save 600ms later. Keeps the UX as "edit and back" — no save
  // button needed — but still batches keystrokes so we don't hammer /auth/me/ on every character typed.
  // (Spec sketch shows no save button at the bottom, just logout + delete.)

  @override
  void dispose() { _last.dispose(); _first.dispose(); _patronymic.dispose(); super.dispose(); }

  void _hydrateFromUser(User u) {
    if (_hydrated) return;
    _hydrated = true;
    // Fallback: split full_name when the structured fields are empty (legacy + phone-registered accounts).
    final fallback = u.fullName.trim().split(RegExp(r'\s+'));
    _last.text = (u.lastName?.isNotEmpty ?? false) ? u.lastName! : (fallback.length > 1 ? fallback.first : '');
    _first.text = (u.firstName?.isNotEmpty ?? false) ? u.firstName!
                  : (fallback.length > 1 ? fallback.sublist(1).join(' ') : fallback.first);
    _patronymic.text = u.patronymic ?? '';
    _dob = (u.dateOfBirth?.isNotEmpty ?? false) ? DateTime.tryParse(u.dateOfBirth!) : null;
    _gender = u.gender;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() { _saving = true; _err = null; });
    try {
      final updated = await ref.read(authRepositoryProvider).updateMe(
        lastName: _last.text.trim(),
        firstName: _first.text.trim(),
        patronymic: _patronymic.text.trim(),
        dateOfBirth: _dob == null ? '' : _formatDate(_dob!),       // empty string clears server-side
        gender: _gender,
      );
      ref.read(authNotifierProvider.notifier).updateUser(updated); // refresh hero name on the parent profile tab
    } on AuthException catch (e) {
      if (mounted) setState(() => _err = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // YYYY-MM-DD — matches Django DateField's wire format and the User dart model's stored representation.
  String _formatDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _dob ?? DateTime(now.year - 25, now.month, now.day);    // sensible default — adult buyer
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1925),                                            // 100 years back covers any realistic buyer
      lastDate: now,                                                        // future DOB makes no sense
      helpText: AppLocalizations.of(context).profileFieldDateOfBirth,
    );
    if (picked != null && picked != _dob) {
      setState(() => _dob = picked);
      await _save();                                                        // save immediately on pick — feels snappy
    }
  }

  Future<void> _confirmDelete() async {
    final t = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(context: context, builder: (dctx) => AlertDialog(
      title: Text(t.deleteAccountConfirmTitle),
      content: Text(t.deleteAccountConfirmBody),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dctx, false), child: Text(t.no)),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Theme.of(dctx).colorScheme.error),
          onPressed: () => Navigator.pop(dctx, true), child: Text(t.deleteAccountConfirmYes)),
      ]));
    if (confirmed != true) return;
    try {
      await ref.read(authRepositoryProvider).deleteAccount();
      await ref.read(authNotifierProvider.notifier).logout();                // wipe local tokens + flip to AuthAnonymous
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final auth = ref.watch(authNotifierProvider);
    // Anonymous fallback — settings screen is meaningless without a user. Pop back to parent if state regressed.
    if (auth is! AuthAuthenticated) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    _hydrateFromUser(auth.user);

    return Scaffold(
      appBar: AppBar(title: Text(t.profileSettingsTitle), elevation: 0),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 32), children: [
        _LabeledField(label: t.profileFieldLastName,
          child: _BoxedTextField(controller: _last, onEditingComplete: _save,
              textCapitalization: TextCapitalization.words)),
        _LabeledField(label: t.profileFieldFirstName,
          child: _BoxedTextField(controller: _first, onEditingComplete: _save,
              textCapitalization: TextCapitalization.words)),
        _LabeledField(label: t.profileFieldPatronymic,
          child: _BoxedTextField(controller: _patronymic, onEditingComplete: _save,
              textCapitalization: TextCapitalization.words, hint: t.profileFieldPatronymicHint)),
        // Date of birth — tap-to-open calendar; field surface mimics the text inputs above.
        _LabeledField(label: t.profileFieldDateOfBirth, child: _DateBox(
          value: _dob == null ? null : _formatDate(_dob!),
          placeholder: t.profileFieldDateOfBirthHint,
          onTap: _pickDob,
        )),
        // Gender — two-up segmented; tapping commits the change immediately.
        _LabeledField(label: t.profileFieldGender, child: _GenderToggle(
          value: _gender,
          onChanged: (g) async {
            setState(() => _gender = g);
            await _save();
          },
        )),
        // Phone — read-only; show the country flag matching the +998 prefix per the v3.2 phone-auth scope.
        _LabeledField(label: t.profileFieldPhone, child: _BoxedTextField(
          controller: TextEditingController(text: auth.user.phone),
          enabled: false,                                                  // server-managed — change via OTP later
          prefix: Padding(padding: const EdgeInsets.only(right: 8),
              child: ClipOval(child: Container(width: 22, height: 22,
                color: cs.surfaceContainerHighest,
                child: const Center(child: Text('🇺🇿', style: TextStyle(fontSize: 14)))))),
        )),
        if (_err != null) Padding(padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(_err!, style: tt.bodyMedium?.copyWith(color: cs.error))),
        const SizedBox(height: 24),
        // ---- Danger zone — Chiqish, then Akkauntni o'chirish in red ----
        OutlinedButton.icon(
          icon: Icon(Icons.logout, color: cs.onSurface),
          label: Text(t.logout, style: TextStyle(color: cs.onSurface)),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48),
              side: BorderSide(color: cs.outlineVariant)),
          onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          icon: Icon(Icons.delete_outline, color: cs.error),
          label: Text(t.deleteAccount, style: TextStyle(color: cs.error)),
          style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: _confirmDelete,
        ),
        // Saving indicator — quiet bottom strip so the user knows their change went through after _save() finishes.
        if (_saving) Padding(padding: const EdgeInsets.only(top: 12),
            child: Center(child: SizedBox(height: 18, width: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary)))),
      ]),
    );
  }
}


/// Label-on-top field row used throughout the settings list. Keeps section spacing consistent.
class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(label, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant))),
        child,
      ]));
  }
}


/// Reusable rounded-card text input matching the screenshot's grey-bordered field look.
class _BoxedTextField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onEditingComplete;
  final TextCapitalization textCapitalization;
  final String? hint;
  final bool enabled;
  final Widget? prefix;
  const _BoxedTextField({required this.controller, this.onEditingComplete,
      this.textCapitalization = TextCapitalization.none, this.hint, this.enabled = true, this.prefix});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(color: enabled ? cs.surface : cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant, width: 0.8)),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(children: [
        ?prefix,  // null-aware list element — entry is dropped entirely when prefix is null
        Expanded(child: TextField(
          controller: controller, enabled: enabled,
          textCapitalization: textCapitalization,
          onEditingComplete: () { FocusManager.instance.primaryFocus?.unfocus(); onEditingComplete?.call(); },
          onTapOutside: (_) { FocusManager.instance.primaryFocus?.unfocus(); onEditingComplete?.call(); },
          decoration: InputDecoration(
            isCollapsed: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            border: InputBorder.none, enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none, disabledBorder: InputBorder.none,
            hintText: hint,
          ),
        )),
      ]),
    );
  }
}


/// Date-of-birth picker trigger — looks identical to _BoxedTextField but is non-editable; calendar opens on tap.
class _DateBox extends StatelessWidget {
  final String? value;
  final String placeholder;
  final VoidCallback onTap;
  const _DateBox({required this.value, required this.placeholder, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(color: Colors.transparent, child: InkWell(onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant, width: 0.8)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Row(children: [
          Expanded(child: Text(value ?? placeholder,
              style: tt.bodyLarge?.copyWith(
                  color: value == null ? cs.onSurfaceVariant : cs.onSurface))),
          Icon(Icons.calendar_today_outlined, size: 20, color: cs.onSurfaceVariant),
        ]),
      )));
  }
}


/// Erkak / Ayol segmented toggle. Bigger and chunkier than Material's SegmentedButton to match the screenshot's
/// pill-shaped panel with a rounded selected chip inside it.
class _GenderToggle extends StatelessWidget {
  final UserGender? value;
  final ValueChanged<UserGender> onChanged;
  const _GenderToggle({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.all(4),
      child: Row(children: [
        for (final g in UserGender.values)
          Expanded(child: _GenderChip(
            label: g == UserGender.male
                ? AppLocalizations.of(context).genderMale
                : AppLocalizations.of(context).genderFemale,
            selected: value == g,
            onTap: () => onChanged(g),
            selectedColor: cs.surface,
            selectedText: tt.titleSmall?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w600),
            unselectedText: tt.titleSmall?.copyWith(color: cs.onSurfaceVariant),
          )),
      ]),
    );
  }
}


class _GenderChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedColor;
  final TextStyle? selectedText, unselectedText;
  const _GenderChip({required this.label, required this.selected, required this.onTap,
      required this.selectedColor, required this.selectedText, required this.unselectedText});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: AnimatedContainer(
      duration: const Duration(milliseconds: 160), curve: Curves.easeOut,
      decoration: BoxDecoration(color: selected ? selectedColor : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: selected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4, offset: const Offset(0, 1))] : null),
      padding: const EdgeInsets.symmetric(vertical: 12),
      alignment: Alignment.center,
      child: Text(label, style: selected ? selectedText : unselectedText),
    ));
  }
}
