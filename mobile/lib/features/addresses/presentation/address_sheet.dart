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
import 'package:shared_preferences/shared_preferences.dart';

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
    // Fallback when no address is saved: the GPS-detected location the home pill is already showing.
    // The user said "even if set by the system when I allow, it should be seen as location set" — so this
    // sheet should reflect the same source the pill does, not pretend the location is empty.
    final autoDetected = ref.watch(currentLocationProvider).asData?.value;

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

        // Body — three branches:
        //   1. Saved address selected → tap row to edit it
        //   2. No saved address but GPS resolved → show the auto-detected location as the current address,
        //      tap row to refine on the map (and save it permanently)
        //   3. No saved + no GPS (permission denied / off) → fall back to the empty-state hint
        if (selected != null)
          _AddressRow(address: selected,
            onTap: () { Navigator.pop(context); context.push('/addresses/${selected.id}'); })
        else if (autoDetected != null)
          _AutoDetectedRow(location: autoDetected,
            // Tap → jump to the map picker with the auto-detected coords as the starting pin so the user
            // can fine-tune + label + save it permanently. Once saved it becomes the selected address and
            // this branch falls back to #1.
            onTap: () {
              Navigator.pop(context);
              context.push('/addresses/map', extra: {
                'initialLat': autoDetected.lat, 'initialLng': autoDetected.lng,
              });
            })
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

        // ---- TEST HELPER (dev only) — drop a Yunusobod-area location into the cached GPS coords ----
        // The Android Studio emulator's default Pixel 7 location is in the US, which makes the cart
        // and delivery quote unusable until the buyer sets a real address. This button writes a
        // Yunusobod fix to SharedPreferences (the same keys the GPS resolver caches) + invalidates
        // currentLocationProvider so the home pill, cart, and delivery page all snap to Tashkent.
        // Remove once a real "set on map" flow is wired in for testers.
        const SizedBox(height: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              foregroundColor: cs.primary),
          icon: const Icon(Icons.bug_report_outlined, size: 18),
          label: Text(t.testUseYunusobod),
          onPressed: () async {
            HapticFeedback.selectionClick();
            final messenger = ScaffoldMessenger.of(context);
            final prefs = await SharedPreferences.getInstance();
            // Yunusobod district center — close to Bunyodkor / Yunus Rajabiy. The resolver's Tashkent
            // bbox covers this comfortably (lat 41.36, lng 69.29).
            await prefs.setDouble('loc.lat', 41.3680);
            await prefs.setDouble('loc.lng', 69.2873);
            // CRITICAL: also clear any saved address selection. effectiveDeliveryLocationProvider
            // checks selectedAddressProvider FIRST and short-circuits — without this clear, the test
            // button updates GPS but the cart/delivery still render the old "Uy" address.
            await ref.read(selectedAddressIdProvider.notifier).set(null);
            // Invalidate so the FutureProvider re-runs and reverse-geocodes the new coord. Every
            // consumer (home pill, cart row, delivery resolver) updates automatically.
            ref.invalidate(currentLocationProvider);
            if (!context.mounted) return;
            Navigator.pop(context);
            messenger.showSnackBar(SnackBar(content: Text(t.testYunusobodApplied)));
          }),
      ])));
  }

  /// Common chrome — rounded top corners, surface fill, SafeArea below for gesture nav.
  Widget _wrap(ColorScheme cs, {required Widget child}) => Container(
    decoration: BoxDecoration(color: cs.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22))),
    child: SafeArea(top: false, child: child),
  );
}


/// Row shown when the user has no SAVED address but the GPS auto-detected one. Visually the same shape as
/// `_AddressRow` so the sheet feels consistent, with a small "Aniqlangan joylashuv" subtitle so the user
/// knows it came from the system and tapping refines it on the map (which then saves it permanently).
class _AutoDetectedRow extends ConsumerWidget {
  final CurrentLocation location;
  final VoidCallback onTap;
  const _AutoDetectedRow({required this.location, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    // Sentinel (reverse-geocode failed) → show localized "Mening joylashuvim" instead of the raw sentinel.
    final cityLabel = location.cityOrArea == kCurrentLocationFallbackLabel
        ? t.addressMapMyLocation : location.cityOrArea;
    final detail = location.regionOrCountry.isNotEmpty
        ? '$cityLabel · ${location.regionOrCountry}'
        : cityLabel;
    return Material(color: cs.surfaceContainerLowest, borderRadius: BorderRadius.circular(16),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16),
        child: Padding(padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12)),
              // Use a "near me" icon so the row reads as "current location" rather than a generic saved place
              child: Icon(Icons.my_location_rounded, color: cs.primary, size: 22)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(detail, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              // Subtle hint — without this, the user might wonder why the address isn't editable from here.
              // Tapping opens the map so they can pin a precise spot + save it as their real Uy / Ofis address.
              Text(t.addressAutoDetectedHint,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            ])),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, size: 20, color: cs.onSurfaceVariant),
          ]))),
    );
  }
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
