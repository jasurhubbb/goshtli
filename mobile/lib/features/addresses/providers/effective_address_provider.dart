// EffectiveDeliveryLocation — unified location resolver used by Cart, Delivery page, and any other
// surface that needs "the lat/lng we'd actually deliver to".
//
// The cart page used to read selectedAddressProvider directly, which broke for users who'd granted GPS
// permission (so the home pill showed their auto-detected city) but never saved a named Address — cart
// said "location isn't determined" while home showed the city. This provider papers over that gap by
// falling back through saved address → GPS-detected location → Tashkent center.
//
// PRD §3 + v3.6 product decision: the marketplace currently delivers ONLY inside Tashkent city/region.
// Coords outside the Tashkent bbox get snapped to Tashkent center so dev/emulator builds (Android
// Studio's default Pixel 7 location is in the US) still produce a usable quote. The UI surfaces a small
// "Hozircha faqat Toshkent" banner when this snap happens so the user knows it's intentional.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/address_model.dart';
import 'addresses_providers.dart';


/// Roughly the city + close suburbs. Anything outside this box is treated as "out of service area" and
/// snapped to Tashkent center for v1. Bbox is hand-tuned (slightly generous on the east + south so
/// Yangiyul and Qibray stay in).
const double _kTashkentLatMin = 41.10;
const double _kTashkentLatMax = 41.55;
const double _kTashkentLngMin = 69.00;
const double _kTashkentLngMax = 69.65;
const double _kTashkentCenterLat = 41.3111;
const double _kTashkentCenterLng = 69.2797;


bool _insideTashkent(double lat, double lng) =>
    lat >= _kTashkentLatMin && lat <= _kTashkentLatMax &&
    lng >= _kTashkentLngMin && lng <= _kTashkentLngMax;


/// What the delivery + cart UIs render and what the delivery quote endpoint receives. Composed from
/// the saved Address (if any) + the GPS-detected current location (if any).
class EffectiveDeliveryLocation {
  /// The saved Address row, if the buyer picked one. Null when relying purely on GPS.
  final Address? savedAddress;

  /// Latitude in degrees — guaranteed inside the Tashkent bbox (snapped if necessary).
  final double lat;

  /// Longitude — same snap rule.
  final double lng;

  /// Title text the UI should show on the address row (e.g. "Uy", "Mening joylashuvim", "Aniqlanmoqda").
  final String label;

  /// Second-line text for the address row (e.g. street name, "Toshkent", "Manzilni aniqlash uchun bosing").
  final String addressLine;

  /// True when the lat/lng came from outside Tashkent and we snapped them. UI shows a banner so the
  /// buyer knows the quote applies to Tashkent, not their actual GPS coord.
  final bool snappedToTashkent;

  /// True when we have NO real signal — neither a saved address nor a GPS fix. The UI uses this to
  /// nudge the buyer to set an address (still produces a Tashkent-centered fallback quote so the rest
  /// of the screen renders, but the address row says "tap to set").
  final bool unresolved;

  const EffectiveDeliveryLocation({
    required this.savedAddress,
    required this.lat,
    required this.lng,
    required this.label,
    required this.addressLine,
    required this.snappedToTashkent,
    required this.unresolved,
  });
}


/// The resolver. Watches both the saved-address provider AND the GPS provider so we react to either.
final effectiveDeliveryLocationProvider = Provider<EffectiveDeliveryLocation>((ref) {
  final saved = ref.watch(selectedAddressProvider);
  final gpsAsync = ref.watch(currentLocationProvider);

  // ---- Case 1: buyer picked a saved Address ----
  if (saved != null) {
    final hasCoords = saved.lat != null && saved.lng != null;
    final inside = hasCoords && _insideTashkent(saved.lat!, saved.lng!);
    return EffectiveDeliveryLocation(
      savedAddress: saved,
      lat: inside ? saved.lat! : _kTashkentCenterLat,
      lng: inside ? saved.lng! : _kTashkentCenterLng,
      label: saved.label,
      addressLine: saved.address,
      snappedToTashkent: hasCoords && !inside,
      unresolved: false,
    );
  }

  // ---- Case 2: GPS resolved (with or without a pretty city name) ----
  final gps = gpsAsync.asData?.value;
  if (gps != null) {
    final inside = _insideTashkent(gps.lat, gps.lng);
    // Use the city name when reverse-geocoding succeeded; otherwise the fallback sentinel that the
    // UI translates into "Mening joylashuvim".
    return EffectiveDeliveryLocation(
      savedAddress: null,
      lat: inside ? gps.lat : _kTashkentCenterLat,
      lng: inside ? gps.lng : _kTashkentCenterLng,
      label: gps.cityOrArea.isNotEmpty ? gps.cityOrArea : kCurrentLocationFallbackLabel,
      addressLine: gps.regionOrCountry.isNotEmpty ? gps.regionOrCountry : 'Toshkent',
      snappedToTashkent: !inside,
      unresolved: false,
    );
  }

  // ---- Case 3: nothing resolved yet (GPS still loading, or permission denied) ----
  // Return a Tashkent-centered fallback so the quote endpoint still has coords to compute against.
  return const EffectiveDeliveryLocation(
    savedAddress: null,
    lat: _kTashkentCenterLat,
    lng: _kTashkentCenterLng,
    label: '',
    addressLine: '',
    snappedToTashkent: false,
    unresolved: true,
  );
});
