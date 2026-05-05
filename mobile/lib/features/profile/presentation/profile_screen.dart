// Profile screen — Apple-style hero (avatar + name + role badge), grouped editable fields below.
//
// Edits go through ProfileRepository, then we invalidate dashboard providers so home re-renders fresh totals on return.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/language_picker.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/providers/auth_state.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../providers/profile_providers.dart';


class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final auth = ref.watch(authNotifierProvider);
    if (auth is! AuthAuthenticated) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final user = auth.user;
    final roleLabel = user.isSupplier ? t.roleSupplier : user.isBuyer ? t.roleBuyer : t.roleAdmin;
    return Scaffold(
      appBar: AppBar(title: Text(t.profileTitle), actions: const [LanguagePicker()]),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
        _UserHero(name: user.fullName, email: user.email, phone: user.phone, role: roleLabel),
        const SizedBox(height: 24),
        if (user.isSupplier) const _SupplierProfileCard()
        else if (user.isBuyer) const _BuyerProfileCard()
        else Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(t.profileAdminViaDjango,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant))),
      ]),
    );
  }
}


/// Centered avatar + name + email/phone + role pill — Apple-style profile hero.
class _UserHero extends StatelessWidget {
  final String name, email, phone, role;
  const _UserHero({required this.name, required this.email, required this.phone, required this.role});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final initials = name.split(' ').take(2).map((s) => s.isEmpty ? '' : s[0]).join().toUpperCase();
    return Column(children: [
      Container(width: 88, height: 88,
        decoration: BoxDecoration(shape: BoxShape.circle,
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [cs.primaryContainer, cs.tertiaryContainer])),
        child: Center(child: Text(initials,
          style: tt.headlineMedium?.copyWith(color: cs.onPrimaryContainer, fontWeight: FontWeight.w600)))),
      const SizedBox(height: 14),
      Text(name, style: tt.headlineSmall),
      const SizedBox(height: 2),
      Text(email, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
      if (phone.isNotEmpty) Text(phone, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
      const SizedBox(height: 10),
      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: cs.secondaryContainer.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(999)),
        child: Text(role, style: tt.labelMedium?.copyWith(color: cs.onSecondaryContainer))),
    ]);
  }
}


/// Buyer-side profile editor — single grouped form bound to /buyers/me/.
class _BuyerProfileCard extends ConsumerStatefulWidget {
  const _BuyerProfileCard();
  @override
  ConsumerState<_BuyerProfileCard> createState() => _BuyerProfileCardState();
}


class _BuyerProfileCardState extends ConsumerState<_BuyerProfileCard> {
  final _business = TextEditingController();
  final _region = TextEditingController();
  final _address = TextEditingController();
  bool _hydrated = false; bool _saving = false; String? _msg;

  @override
  void dispose() { _business.dispose(); _region.dispose(); _address.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final async = ref.watch(myBuyerProfileProvider);
    return async.when(
      data: (p) {
        if (!_hydrated) {
          _business.text = p.businessName; _region.text = p.region; _address.text = p.address; _hydrated = true;
        }
        return _ProfileFormShell(title: t.buyerProfileTitle, fields: [_business, _region, _address],
          labels: [t.profileFieldBusinessName, t.profileFieldRegion, t.profileFieldAddress],
          msg: _msg, saving: _saving, saveLabel: t.listingActionSave,
          onSave: () async {
            setState(() { _saving = true; _msg = null; });
            try {
              await ref.read(profileRepositoryProvider).patchBuyerProfile(
                  businessName: _business.text, region: _region.text, address: _address.text);
              ref..invalidate(myBuyerProfileProvider)..invalidate(buyerDashboardProvider);
              if (mounted) setState(() => _msg = t.profileSavedSnack);
            } catch (e) { if (mounted) setState(() => _msg = e.toString()); }
            finally { if (mounted) setState(() => _saving = false); }
          });
      },
      loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Text(t.failedPrefix(e.toString())),
    );
  }
}


/// Supplier-side profile editor — same shape as buyer's plus a verification badge near the title.
class _SupplierProfileCard extends ConsumerStatefulWidget {
  const _SupplierProfileCard();
  @override
  ConsumerState<_SupplierProfileCard> createState() => _SupplierProfileCardState();
}


class _SupplierProfileCardState extends ConsumerState<_SupplierProfileCard> {
  final _business = TextEditingController();
  final _region = TextEditingController();
  final _address = TextEditingController();
  bool _hydrated = false; bool _saving = false; String? _msg;

  @override
  void dispose() { _business.dispose(); _region.dispose(); _address.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final async = ref.watch(mySupplierProfileProvider);
    return async.when(
      data: (p) {
        if (!_hydrated) {
          _business.text = p.businessName; _region.text = p.region; _address.text = p.address; _hydrated = true;
        }
        return _ProfileFormShell(title: t.supplierProfileTitle, fields: [_business, _region, _address],
          labels: [t.profileFieldBusinessName, t.profileFieldRegion, t.profileFieldAddress],
          titleTrailing: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: (p.isVerified ? cs.tertiaryContainer : cs.errorContainer).withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(999)),
            child: Text(p.isVerified ? t.profileVerified : t.profileUnverified,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: p.isVerified ? cs.onTertiaryContainer : cs.onErrorContainer))),
          msg: _msg, saving: _saving, saveLabel: t.listingActionSave,
          onSave: () async {
            setState(() { _saving = true; _msg = null; });
            try {
              await ref.read(profileRepositoryProvider).patchSupplierProfile(
                  businessName: _business.text, region: _region.text, address: _address.text);
              ref..invalidate(mySupplierProfileProvider)..invalidate(supplierDashboardProvider);
              if (mounted) setState(() => _msg = t.profileSavedSnack);
            } catch (e) { if (mounted) setState(() => _msg = e.toString()); }
            finally { if (mounted) setState(() => _saving = false); }
          });
      },
      loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Text(t.failedPrefix(e.toString())),
    );
  }
}


/// Shared shell for both profile editors — handles section header, field stack, save button, status message.
class _ProfileFormShell extends StatelessWidget {
  final String title;
  final Widget? titleTrailing;
  final List<TextEditingController> fields;
  final List<String> labels;
  final String? msg;
  final bool saving;
  final String saveLabel;
  final VoidCallback onSave;

  const _ProfileFormShell({required this.title, this.titleTrailing, required this.fields, required this.labels,
                           required this.msg, required this.saving, required this.saveLabel, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.fromLTRB(8, 0, 0, 10),
        child: Row(children: [
          Expanded(child: Text(title.toUpperCase(),
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant, letterSpacing: 0.6))),
          ?titleTrailing,  // null-aware list element — entry is dropped when titleTrailing is null
        ])),
      for (int i = 0; i < fields.length; i++) ...[
        TextField(controller: fields[i], maxLines: i == fields.length - 1 ? 2 : 1,
          decoration: InputDecoration(labelText: labels[i])),
        const SizedBox(height: 12),
      ],
      if (msg != null) Padding(padding: const EdgeInsets.only(top: 4, bottom: 8), child: Text(msg!)),
      const SizedBox(height: 8),
      FilledButton(onPressed: saving ? null : onSave,
        child: saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(saveLabel)),
    ]);
  }
}
