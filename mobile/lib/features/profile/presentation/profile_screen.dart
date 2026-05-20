// Profile screen — Apple-style hero (avatar + name + role badge), grouped editable fields, Mening… shortcuts, settings.
//
// v2 additions: "Mening buyurtmalarim" / "Mening e'lonlarim" shortcuts (Orders + My listings nested under Profile tab),
// "Hisobni o'chirish" (Play Store required), language picker, logout.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/locale/locale_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/language_picker.dart';
import '../../../shared/widgets/privacy_tagline.dart';
import '../../auth/data/auth_repository.dart';
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
    // v3 pivot: Profile tab handles three states distinctly. Anonymous users see a clear sign-in CTA so they know
    // why their orders/saved items aren't here yet.
    if (auth is AuthAnonymous || auth is AuthUnauthenticated) return const _AnonymousProfile();
    if (auth is! AuthAuthenticated) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final user = auth.user;
    final roleLabel = user.isSupplier ? t.roleSupplier : user.isBuyer ? t.roleBuyer : t.roleAdmin;
    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar.large(title: Text(t.profileTitle), actions: const [LanguagePicker()]),
        SliverPadding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), sliver: SliverList.list(children: [
          _UserHero(name: user.fullName, email: user.email, phone: user.phone, role: roleLabel),
          const SizedBox(height: 24),
          // v3 pivot: buyer-only shortcuts. "Mening e'lonlarim" removed since sellers don't exist on the mobile side.
          _GroupedShortcuts(items: [
            (Icons.receipt_long_outlined, t.myOrders, () => context.go('/profile/orders')),
            (Icons.favorite_border, t.savedListingsTitle, () => context.push('/profile/saved')),
          ]),
          const SizedBox(height: 24),
          if (user.isSupplier) const _SupplierProfileCard()
          else if (user.isBuyer) const _BuyerProfileCard()
          else Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(t.profileAdminViaDjango,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant))),
          const SizedBox(height: 32),
          // Danger zone — logout + delete account (Play Store requires the delete option)
          const _DangerZone(),
        ])),
      ]),
    );
  }
}


/// Profile screen for anonymous users (v3 pivot, Instamart-style design).
///
/// Layout: top hero is a brand-coloured section that fills the screen down to ~58% — hosts the for-profile-page.png
/// illustration (sized to fit, never cropped). Below the hero, a white panel with rounded top corners holds a primary
/// "Kirish" CTA, the privacy/terms tagline, a single rounded-card row for "Ilova tili" (replacing Offers/Feedback in
/// the reference), and the app version line.
class _AnonymousProfile extends ConsumerWidget {
  const _AnonymousProfile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final currentLocale = ref.watch(localeNotifierProvider);
    // Self-name each language in its own script — what the user actually sees in the row "value" slot
    final localeLabel = switch (currentLocale.languageCode) {
      'ru' => 'Русский', 'uz' => "O'zbekcha", _ => currentLocale.languageCode };
    // Hero colour: deep-red brand seed (matches the Instamart reference's full-bleed top section)
    final heroColor = cs.primary;

    return Scaffold(
      // Body extends behind the status bar so the hero color reaches the top edge — matches the Instamart screenshot
      backgroundColor: heroColor,
      body: Column(children: [
        // ---------- Hero (brand-colour, hosts the illustration pinned to the top) ----------
        // SafeArea handles the status-bar inset. The image fills the screen width and auto-sizes to its natural
        // aspect-ratio height — no Expanded/Center, so no blank red bands above or below.
        SafeArea(bottom: false, child: Image.asset('assets/images/for-profile-page.png',
            width: double.infinity, fit: BoxFit.fitWidth,
            alignment: Alignment.topCenter, filterQuality: FilterQuality.medium)),

        // ---------- White bottom panel with rounded top corners ----------
        // Expanded so the panel grabs all remaining vertical space — its content stays top-aligned, the rest is
        // surface-colour fill (matches Instamart's layout where the panel reaches the tab bar).
        Expanded(child: Container(width: double.infinity,
          decoration: BoxDecoration(color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
          child: SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Primary CTA — full-width "Sign in", routes to /register (login screen has a "Have account?" link)
              SizedBox(width: double.infinity, height: 52, child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: heroColor, foregroundColor: cs.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () => context.push('/register'),
                child: Text(t.signIn, style: tt.titleMedium?.copyWith(
                    color: cs.onPrimary, fontWeight: FontWeight.w600)))),
              const SizedBox(height: 12),
              // Reusable PrivacyTagline — owns the link-span splitting so any auth/onboarding screen can drop it in
              const PrivacyTagline(),
              const SizedBox(height: 20),
              // Single rounded-card row — only "App language" per the spec (Offers/Feedback in the reference removed).
              _SettingsCard(child: _SettingsTile(
                leading: const Text('🇺🇿', style: TextStyle(fontSize: 22)),
                label: t.appLanguage,
                value: localeLabel,
                onTap: () => showLanguageSheet(context, ref))),
              const SizedBox(height: 16),
              Center(child: Text(t.appVersionLabel('1.0.0'),
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant))),
            ]))))),
      ]),
    );
  }
}


/// Rounded-card wrapper used for grouped settings rows in the anonymous profile.
class _SettingsCard extends StatelessWidget {
  final Widget child;
  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(decoration: BoxDecoration(color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4), width: 0.5)),
      clipBehavior: Clip.antiAlias,
      child: child);
  }
}


/// Reusable settings-row tile — flag/icon, label, right-aligned value text, chevron. Used inside _SettingsCard.
class _SettingsTile extends StatelessWidget {
  final Widget leading;
  final String label;
  final String? value;
  final VoidCallback onTap;
  const _SettingsTile({required this.leading, required this.label, required this.onTap, this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return InkWell(onTap: onTap, child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        SizedBox(width: 28, child: Center(child: leading)),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: tt.bodyLarge)),
        if (value != null) Text(value!, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(width: 4),
        Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
      ])));
  }
}


/// Grouped iOS-style shortcuts row (rounded surface, hairline dividers, chevrons).
class _GroupedShortcuts extends StatelessWidget {
  final List<(IconData, String, VoidCallback)> items;
  const _GroupedShortcuts({required this.items});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(decoration: BoxDecoration(color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5), width: 0.5)),
      child: Column(children: [
        for (int i = 0; i < items.length; i++) ...[
          ListTile(
            leading: Icon(items[i].$1, color: cs.primary),
            title: Text(items[i].$2, style: Theme.of(context).textTheme.bodyLarge),
            trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            onTap: items[i].$3,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          ),
          if (i < items.length - 1) Padding(padding: const EdgeInsets.only(left: 56),
              child: Divider(height: 0.5, color: cs.outlineVariant.withValues(alpha: 0.5))),
        ],
      ]));
  }
}


/// Logout + delete account — destructive actions kept visually separate from the rest of the form.
class _DangerZone extends ConsumerWidget {
  const _DangerZone();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      OutlinedButton.icon(icon: Icon(Icons.logout, color: cs.onSurface),
        label: Text(t.logout, style: TextStyle(color: cs.onSurface)),
        onPressed: () => ref.read(authNotifierProvider.notifier).logout()),
      const SizedBox(height: 12),
      TextButton.icon(icon: Icon(Icons.delete_outline, color: cs.error),
        label: Text(t.deleteAccount, style: TextStyle(color: cs.error)),
        onPressed: () => _confirmDelete(context, ref)),
    ]);
  }

  /// Two-step confirmation — first dialog asks Are you sure?, then we hit DELETE /auth/me/. If the API returns 409
  /// (active orders block delete) we surface the server's message inline.
  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
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
      await ref.read(authNotifierProvider.notifier).logout();  // ensure local tokens are wiped + UI bounces to login
    } on AuthException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
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
