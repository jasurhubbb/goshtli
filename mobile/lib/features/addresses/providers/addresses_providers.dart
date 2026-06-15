// Riverpod providers for the buyer's saved-address layer.
//
// Concerns:
//   1. `addressesProvider` — holds the list. AsyncNotifier-style: load once at construction, then mutate
//      synchronously via add/update/delete. No invalidate-then-wait window where the UI shows "loading" and
//      a freshly-saved address briefly disappears from the home pill / sheet.
//   2. `selectedAddressIdProvider` — which address is currently active for the cart / home pill. Persists
//      across app sessions via SharedPreferences (stored by id; resolved into Address via the list).
//   3. `currentLocationProvider` — auto-detected location for users with no saved address (anonymous or
//      newly-signed-in). One-shot Geolocator + Nominatim reverse-geocode; cached for the session.
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/providers/auth_providers.dart';
import '../data/address_model.dart';
import '../data/addresses_gateway.dart';
import '../data/addresses_repository.dart';
import '../data/local_addresses_store.dart';


final addressesRepositoryProvider = Provider<AddressesRepository>((ref) =>
    AddressesRepository(ref.watch(apiClientProvider)));

final localAddressesStoreProvider = Provider<LocalAddressesStore>((ref) => LocalAddressesStore());

/// Gateway dispatches every CRUD operation to the right store based on current auth state.
final addressesGatewayProvider = Provider<AddressesGateway>((ref) => AddressesGateway(
      auth: ref.watch(authNotifierProvider),
      backend: ref.watch(addressesRepositoryProvider),
      local: ref.watch(localAddressesStoreProvider),
    ));


/// AsyncNotifier-style holder for the address list. Loads from the gateway on init, then mutates state
/// synchronously after each create/update/delete so widgets that watch `addressesProvider` see the change
/// immediately — no "loading" intermediate state, no race with navigation.
///
/// Why not a FutureProvider + ref.invalidate? Invalidate puts the provider back into AsyncValue.loading
/// while the new future runs. During that window `asData?.value` is null → selectedAddressProvider returns
/// null → the home pill shows fallback. By the time the future resolves, the user has already navigated.
/// On some Riverpod versions, the post-resolve rebuild doesn't reach the pill if the listener subscription
/// was set up across a pop. Holding the list in a notifier eliminates all of that.
class AddressesNotifier extends StateNotifier<AsyncValue<List<Address>>> {
  final AddressesGateway _gateway;
  AddressesNotifier(this._gateway) : super(const AsyncValue.loading()) { _load(); }

  /// Initial fetch — runs once at construction. Also exposed as `refresh()` for manual reloads.
  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      final list = await _gateway.list();
      debugPrint('[addresses] loaded ${list.length} from gateway');
      state = AsyncValue.data(list);
    } catch (e, st) {
      debugPrint('[addresses] load failed: $e');
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => _load();

  /// Persist + replace any existing addresses. Single-address invariant: a buyer only ever has ONE active
  /// address — saving a new one drops the previous one entirely. Simpler mental model for users; gracefully
  /// handles backward-compat data where multiple rows might exist from an earlier app version.
  Future<Address> add({required String label, required String address,
                       String entrance = '', String floor = '', String apartment = '', String notes = '',
                       double? lat, double? lng}) async {
    // First, delete every existing row so we end up with exactly one. We swallow per-row delete errors —
    // best-effort cleanup; even if the backend rejects an old row, the new one still gets created and the UI
    // state reflects "one address". The user shouldn't be blocked from saving by stale cleanup failures.
    final existing = state.value ?? const <Address>[];
    for (final old in existing) {
      try { await _gateway.delete(old.id); } catch (_) { /* best-effort */ }
    }
    final created = await _gateway.create(label: label, address: address,
        entrance: entrance, floor: floor, apartment: apartment, notes: notes, lat: lat, lng: lng);
    state = AsyncValue.data([created]);
    debugPrint('[addresses] add → id=${created.id} (replaced ${existing.length} previous)');
    return created;
  }

  /// Persist + replace in list. Re-uses the existing index so display order is preserved.
  Future<Address> updateOne(int id, Map<String, dynamic> patch) async {
    final updated = await _gateway.update(id, patch);
    final current = state.value ?? const <Address>[];
    state = AsyncValue.data([for (final a in current) a.id == id ? updated : a]);
    return updated;
  }

  /// Persist + drop from list.
  Future<void> removeOne(int id) async {
    await _gateway.delete(id);
    final current = state.value ?? const <Address>[];
    state = AsyncValue.data(current.where((a) => a.id != id).toList());
  }
}


/// The list. Watch this from the sheet / home pill / cart row. Mutations go through `.notifier.add/...`.
/// Watching the gateway here means a login/logout transition automatically reloads the list from the
/// correct store (backend vs. local).
final addressesProvider = StateNotifierProvider<AddressesNotifier, AsyncValue<List<Address>>>((ref) {
  // ref.watch the gateway so a login/logout rebuilds this notifier with the right backing store
  return AddressesNotifier(ref.watch(addressesGatewayProvider));
});


/// SharedPreferences key for the currently-selected address id. Keeping it as just the id means a deleted
/// address gracefully resolves to null instead of pointing at a stale snapshot.
const _kSelectedAddressIdKey = 'selected_address_id';


/// Notifier wrapping the SharedPreferences-backed "which address is active" pointer.
class SelectedAddressNotifier extends StateNotifier<int?> {
  SelectedAddressNotifier() : super(null) { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getInt(_kSelectedAddressIdKey);
  }

  Future<void> set(int? id) async {
    state = id;  // synchronous — Riverpod listeners see this immediately
    final prefs = await SharedPreferences.getInstance();
    if (id == null) { await prefs.remove(_kSelectedAddressIdKey); }
    else { await prefs.setInt(_kSelectedAddressIdKey, id); }
  }
}


final selectedAddressIdProvider =
    StateNotifierProvider<SelectedAddressNotifier, int?>((ref) => SelectedAddressNotifier());


/// Resolved selected Address — joins selectedAddressIdProvider with addressesProvider so widgets that need
/// to display the active address (home pill, cart screen) bind to ONE provider instead of two.
/// Returns null when no selection OR when the saved id no longer matches a row.
final selectedAddressProvider = Provider<Address?>((ref) {
  final id = ref.watch(selectedAddressIdProvider);
  if (id == null) return null;
  final list = ref.watch(addressesProvider).value ?? const [];
  for (final a in list) { if (a.id == id) return a; }
  return null;
});


/// Compact display-only "current location" payload — city + sub-area from Nominatim, for the home pill.
class CurrentLocation {
  final double lat;
  final double lng;
  final String cityOrArea;
  final String regionOrCountry;
  const CurrentLocation({required this.lat, required this.lng,
                         required this.cityOrArea, required this.regionOrCountry});
}


/// Generic fallback label when we HAVE GPS coords but reverse-geocoding failed (network down, Nominatim
/// rate-limited, etc.). Kept on the Dart side so it doesn't depend on `BuildContext` — the pill maps it
/// to the localized "Mening joylashuvim" string when rendering.
const String kCurrentLocationFallbackLabel = '__current_location__';


/// One-shot async provider: returns the display fields the pill renders. Sources tried, in order:
///   1. Cached lat/lng from onboarding (SharedPreferences `loc.lat`/`loc.lng`) — skips GPS entirely.
///   2. Geolocator.getLastKnownPosition — instant if Android has a recent fix.
///   3. Fresh GPS via Geolocator.getCurrentPosition (low accuracy, 10s timeout).
///
/// CRITICAL: once we have lat/lng from ANY source, we ALWAYS return a CurrentLocation, even when reverse
/// geocoding fails. The pill then shows "Mening joylashuvim" instead of dropping back to "Manzil tanlang"
/// (which was the bug — system-granted location was being silently discarded because Nominatim was slow
/// or failed). The user knows their location is set; tap the pill to refine on the map.
final currentLocationProvider = FutureProvider<CurrentLocation?>((ref) async {
  // ---- Step 1: cached coords from onboarding. Cheapest path. ----
  final prefs = await SharedPreferences.getInstance();
  double? lat = prefs.getDouble('loc.lat');
  double? lng = prefs.getDouble('loc.lng');

  // ---- Step 2 + 3: fall through to GPS if there's no cache ----
  // Track WHY we couldn't get coords so we can differentiate two states:
  //   (a) user denied permission → return null, pill shows "Manzil tanlang" (correct UX)
  //   (b) permission granted but GPS unavailable (emulator with no mock location, slow lock, etc.)
  //       → fall through to Tashkent-centered fallback below. Pill shows "Mening joylashuvim".
  //         Critical on Android emulators which don't have a default position set in Extended Controls.
  bool permissionGranted = false;
  if (lat == null || lng == null) {
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return null;
    permissionGranted = true;
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    // Last-known-position FIRST — returns instantly when the OS has a recent fix, sparing the 10s wait.
    Position? pos = await Geolocator.getLastKnownPosition();
    if (pos == null) {
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 10),                              // was 6s — too tight on cold-start emulator + slow GPS
          ));
      } catch (_) {
        pos = null;                                                        // GPS timed out / not available
      }
    }
    if (pos != null) {
      lat = pos.latitude;
      lng = pos.longitude;
      await prefs.setDouble('loc.lat', lat);
      await prefs.setDouble('loc.lng', lng);
    }
  }

  // Permission granted but no GPS fix (emulator / indoors / GPS off) — surface the sentinel so the pill
  // reads "Mening joylashuvim" instead of "Manzil tanlang". Default coords to Tashkent center so the map
  // picker has something reasonable to show if the user taps to refine. We intentionally DON'T cache
  // these fallback coords — next launch tries GPS again.
  if (lat == null || lng == null) {
    if (permissionGranted) {
      return CurrentLocation(
        lat: 41.3111, lng: 69.2406,                            // Toshkent markaz
        cityOrArea: kCurrentLocationFallbackLabel,
        regionOrCountry: '',
      );
    }
    return null;
  }

  // At this point we DEFINITELY have lat/lng. Reverse-geocoding is a nice-to-have: if it succeeds we get
  // a human-readable city name; if it fails we still return CurrentLocation with the fallback label so
  // the pill never reverts to "Manzil tanlang" after the user already granted permission.
  final dio = Dio(BaseOptions(headers: {'User-Agent': 'goshtli/1.0 (Uzbekistan meat marketplace)'},
                              connectTimeout: const Duration(seconds: 8),
                              receiveTimeout: const Duration(seconds: 8)));
  try {
    final r = await dio.get('https://nominatim.openstreetmap.org/reverse', queryParameters: {
      'lat': lat.toStringAsFixed(6), 'lon': lng.toStringAsFixed(6),
      'format': 'json', 'addressdetails': 1, 'zoom': 14,
      'accept-language': 'uz,ru,en',
    });
    if (r.statusCode == 200 && r.data is Map) {
      final data = r.data as Map<String, dynamic>;
      final addr = data['address'] as Map<String, dynamic>? ?? const {};
      final city = (addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['suburb']
                   ?? addr['neighbourhood'] ?? addr['county'] ?? '').toString();
      final region = (addr['state'] ?? addr['region'] ?? addr['country'] ?? '').toString();
      final resolvedCity = city.isEmpty
          ? (data['display_name'] as String? ?? '').split(',').first
          : city;
      if (resolvedCity.isNotEmpty) {
        return CurrentLocation(lat: lat, lng: lng, cityOrArea: resolvedCity, regionOrCountry: region);
      }
    }
  } catch (_) {
    // network / Nominatim timeout — fall through to the coords-only payload below
  } finally {
    dio.close();
  }

  // Reverse-geocode failed but coords are valid — surface the location with a placeholder label.
  // The pill maps this sentinel to its localized "Mening joylashuvim" string.
  return CurrentLocation(lat: lat, lng: lng,
      cityOrArea: kCurrentLocationFallbackLabel, regionOrCountry: '');
});
