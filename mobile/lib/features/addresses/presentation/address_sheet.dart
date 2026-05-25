// AddressSheet — modal bottom sheet showing the user's single saved address + a "Yangi manzil" CTA.
//
// Single-address invariant (v3.1+): a buyer only ever has ONE active delivery address. Saving a new one
// replaces the previous one entirely — there's no "list" or "switch between addresses" UX. Anonymous users
// store their address in SharedPreferences via LocalAddressesStore; authenticated users get the same surface
// but the gateway routes saves to /api/v1/buyers/addresses/.
//
// Sheet states:
//   • No address yet → empty-state prompt + "Yangi manzil" CTA.
//   • Has address     → the address row (tap to edit) + "Yangi manzil" CTA (which replaces, via the map flow).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../data/address_model.dart';
import '../providers/addresses_providers.dart';


/// Drop-in helper. Sheet uses the root navigator + opaque barrier so it covers the cart floating bar.
Future<void> showAddressSheet(BuildContext context) async {
  final screenHeight = MediaQuery.of(context).size.height;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    constraints: BoxConstraints(maxHeight: screenHeight * 0.88, minHeight: screenHeight * 0.45),
    builder: (_) => const _AddressSheet(),
  );
}


class _AddressSheet extends ConsumerWidget {
  const _AddressSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    // We only ever expose ONE address — the selected one. If there are stale rows from a previous app
    // version, those don't get rendered. The first "Yangi manzil" tap cleans them up.
    final addressesState = ref.watch(addressesProvider);
    final selected = ref.watch(selectedAddressProvider);

    // Loading state on first mount — quick spinner while the local store reads SharedPreferences.
    if (addressesState.isLoading && selected == null) {
      return _wrap(cs, child: const Center(child: Padding(padding: EdgeInsets.all(48),
          child: CircularProgressIndicator())));
    }

    return _wrap(cs, child: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Drag handle — visual only; sheet dismisses on swipe regardless.
        Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 8, bottom: 14),
          decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)))),

        // Header row — title + X close button
        Row(children: [
          Expanded(child: Text(t.addressesTitle, style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
          Material(color: cs.surfaceContainerHighest, shape: const CircleBorder(),
            child: InkResponse(onTap: () => Navigator.pop(context), radius: 20,
              child: Padding(padding: const EdgeInsets.all(6),
                child: Icon(Icons.close_rounded, size: 18, color: cs.onSurface)))),
        ]),
        const SizedBox(height: 18),

        // Body — single address row OR empty-state hint
        if (selected != null)
          _AddressRow(address: selected,
            // Tap row → open edit form pre-populated. The form's `_isEdit` branch handles loading the row
            // from addressesProvider's cached list, so no extra fetch is needed.
            onTap: () { Navigator.pop(context); context.push('/addresses/${selected.id}'); })
        else
          Padding(padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(t.addressesEmpty,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant), textAlign: TextAlign.center)),

        const SizedBox(height: 20),

        // Primary CTA — always present. Routes to the map flow; on save the new address REPLACES the
        // existing one (handled by AddressesNotifier.add).
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54),
              backgroundColor: cs.primary, foregroundColor: cs.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
            context.push('/addresses/map');
          },
          child: Text(t.addressesNewCta,
            style: tt.titleMedium?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w700))),
      ])));
  }

  /// Common chrome — rounded top corners, surface fill, SafeArea below for gesture nav.
  Widget _wrap(ColorScheme cs, {required Widget child}) => Container(
    decoration: BoxDecoration(color: cs.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22))),
    child: SafeArea(top: false, child: child),
  );
}


/// Single-row card showing the active address — home icon chip + label + street + chevron. Tap to edit.
class _AddressRow extends StatelessWidget {
  final Address address;
  final VoidCallback onTap;
  const _AddressRow({required this.address, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(color: cs.surfaceContainerLowest, borderRadius: BorderRadius.circular(16),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16),
        child: Padding(padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.home_rounded, color: cs.primary, size: 24)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(address.label, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(address.address,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            ])),
            const SizedBox(width: 8),
            // Pencil icon affordance — the whole row is tappable but the icon makes the intent obvious.
            Icon(Icons.edit_outlined, size: 20, color: cs.onSurfaceVariant),
          ]))),
    );
  }
}
