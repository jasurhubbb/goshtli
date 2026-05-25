// AddressMapScreen — pin-on-map address picker. Open from the address form, returns (lat, lng, displayName)
// to the caller via context.pop().
//
// Stack:
//   • flutter_map renders OSM tiles (https://tile.openstreetmap.org/{z}/{x}/{y}.png) — completely free, no API key.
//   • A center-fixed marker icon stays in the middle of the screen as the user pans the map (this is the
//     "drop a pin where you actually live" UX from Uzum / Wolt / Bolt — feels natural and accurate).
//   • Each pan settles → reverse-geocode via Nominatim → display the matched street name in the bottom card.
//   • "My location" button uses geolocator to centre on the device's current GPS reading (already-permitted
//     by the v3 onboarding flow; if not granted, we just don't move the map).
//   • "Uy raqamini aniqlashtirish" / "Refine house number" → pop with the (lat, lng, displayName) payload.
//
// OSM tile-server policy: must include a User-Agent. We set the global Dio interceptor to do this for all
// tile + Nominatim requests in api_client.dart. For volume launches we'd switch to a Stadia Maps / MapTiler
// free tier (still no API key for <100k req/mo).
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../l10n/app_localizations.dart';


// Default centre = Tashkent city centre. Used when the user has no prior pin AND we can't read GPS.
const _kDefaultCenter = LatLng(41.311081, 69.240562);

// Nominatim reverse-geocoding base URL. Free, no key. Must include a User-Agent header.
const _kNominatimBase = 'https://nominatim.openstreetmap.org/reverse';


class AddressMapScreen extends ConsumerStatefulWidget {
  /// Optional initial centre. Pass the last-saved lat/lng from the form so re-opening the picker recalls
  /// where the user was, instead of resetting to Tashkent centre every time.
  final double? initialLat;
  final double? initialLng;
  final String? initialQuery;   // if we wanted to forward-geocode a typed query, this is where it'd come in
  const AddressMapScreen({super.key, this.initialLat, this.initialLng, this.initialQuery});

  @override
  ConsumerState<AddressMapScreen> createState() => _AddressMapScreenState();
}


class _AddressMapScreenState extends ConsumerState<AddressMapScreen> {
  late final MapController _map;
  // Centre is tracked in state so the bottom card can show the resolved street name as the user pans.
  LatLng _centre = _kDefaultCenter;
  String _resolvedAddress = '';
  // House number parsed out of Nominatim's address.house_number, when present. Empty when the geocoder
  // couldn't resolve to a specific building — the form will then ask the user for it explicitly.
  String _resolvedHouseNumber = '';
  bool _resolving = false;
  // Debounce reverse-geocode calls — Nominatim has a 1 req/sec rate limit, so we wait until the pan settles.
  Timer? _debounce;
  // Lightweight dedicated Dio so we can set the OSM-required User-Agent without polluting api_client.dart.
  late final Dio _osmDio;

  @override
  void initState() {
    super.initState();
    _map = MapController();
    _osmDio = Dio(BaseOptions(
      // OSM + Nominatim policy: identify the client. https://operations.osmfoundation.org/policies/nominatim/
      headers: {'User-Agent': 'goshtli/1.0 (Uzbekistan meat marketplace)'},
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ));

    // Two paths for the initial map centre:
    //   1. Caller passed explicit coords (edit flow — user is refining an existing address pin) → use those
    //   2. No coords passed (fresh "Yangi manzil") → auto-centre on the user's current location. Start at
    //      Tashkent default for the first paint, then fetch GPS and move once available.
    if (widget.initialLat != null && widget.initialLng != null) {
      _centre = LatLng(widget.initialLat!, widget.initialLng!);
      WidgetsBinding.instance.addPostFrameCallback((_) => _reverseGeocode(_centre));
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _moveToUserLocation());
    }
  }

  /// Auto-centre on the device's current location for the "Yangi manzil" flow. Cache-first:
  ///   • SharedPreferences `loc.lat`/`loc.lng` (set by onboarding + currentLocationProvider) → instant.
  ///   • Fresh GPS via Geolocator if the cache is empty.
  ///   • Silent fail (permission denied / no GPS) → stay at the Tashkent default + reverse-geocode it so the
  ///     bottom card isn't blank. The user can pan manually.
  Future<void> _moveToUserLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedLat = prefs.getDouble('loc.lat');
    final cachedLng = prefs.getDouble('loc.lng');
    if (cachedLat != null && cachedLng != null) {
      if (!mounted) return;
      // _map.move triggers _onMapEvent → debounced reverse-geocode picks up the new centre automatically
      _map.move(LatLng(cachedLat, cachedLng), 17);
      return;
    }
    // No cache → fall through to fresh GPS
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) _reverseGeocode(_centre);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 8)));
      if (!mounted) return;
      // Stash the fresh fix so the next "Yangi manzil" open is instant.
      await prefs.setDouble('loc.lat', pos.latitude);
      await prefs.setDouble('loc.lng', pos.longitude);
      _map.move(LatLng(pos.latitude, pos.longitude), 17);
    } catch (_) {
      if (mounted) _reverseGeocode(_centre);
    }
  }

  @override
  void dispose() { _debounce?.cancel(); _osmDio.close(); super.dispose(); }

  /// Called as the user pans/zooms the map. Debounces (500ms) so we don't spam Nominatim per tile move.
  void _onMapEvent(MapEvent event) {
    // Only respond to events that actually change the centre — every gesture fires many events.
    final newCentre = _map.camera.center;
    if (newCentre.latitude == _centre.latitude && newCentre.longitude == _centre.longitude) return;
    _centre = newCentre;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => _reverseGeocode(_centre));
  }

  /// Hit Nominatim → resolve lat/lng to a human-readable street name. Failures are non-fatal (we just clear
  /// the address text and the user can still save with raw coordinates).
  Future<void> _reverseGeocode(LatLng p) async {
    setState(() => _resolving = true);
    try {
      final r = await _osmDio.get(_kNominatimBase, queryParameters: {
        'lat': p.latitude.toStringAsFixed(6),
        'lon': p.longitude.toStringAsFixed(6),
        'format': 'json',
        'addressdetails': 1,
        'accept-language': Localizations.localeOf(context).languageCode,
        'zoom': 18,
      });
      if (r.statusCode == 200 && r.data is Map<String, dynamic>) {
        final data = r.data as Map<String, dynamic>;
        final name = (data['display_name'] as String?) ?? '';
        // Pull house_number out of the structured address block — Nominatim sometimes has it, often doesn't.
        // When it's present we forward it to the form so the user doesn't have to retype.
        final addr = data['address'] as Map<String, dynamic>? ?? const {};
        final houseNum = (addr['house_number'] as String?) ?? '';
        if (mounted) setState(() {
          _resolvedAddress = name;
          _resolvedHouseNumber = houseNum;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _resolvedAddress = ''; _resolvedHouseNumber = ''; });
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  /// Centre the map on the device's current GPS. Permissions were granted in the v3 onboarding flow; if not,
  /// silently do nothing (user can still pan manually).
  /// timeLimit=8s caps the wait — on a poor GPS signal we'd otherwise hang the FAB forever.
  Future<void> _goToMyLocation() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 8)));
      final p = LatLng(pos.latitude, pos.longitude);
      _map.move(p, 17);
      // The map move triggers _onMapEvent which kicks off reverse-geocode via the normal debounced path.
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).failedPrefix('GPS'))));
    }
  }

  void _confirm() {
    HapticFeedback.lightImpact();
    // Two flows reach this screen:
    //   1. From the new-address sheet: map is the FIRST step → confirm should jump straight to the form so
    //      the user can fill in label/entrance/floor/apt/notes. pushReplacement = back button skips the map.
    //   2. From an existing form's "edit map pin" tap: we want to RETURN the picked coordinates to the form so
    //      it pre-fills without re-asking. We detect this via the `popOnConfirm` extra flag.
    final extra = (GoRouterState.of(context).extra as Map<String, dynamic>?) ?? const {};
    final popOnConfirm = extra['popOnConfirm'] == true;
    // `houseNumber` is empty when Nominatim couldn't pinpoint the building — form will then ask explicitly.
    final payload = {
      'lat': _centre.latitude, 'lng': _centre.longitude,
      'displayName': _resolvedAddress,
      'houseNumber': _resolvedHouseNumber,
    };
    if (popOnConfirm) {
      context.pop(payload);
    } else {
      // Default flow (from "Yangi manzil" CTA): land on the form pre-filled with this location.
      context.pushReplacement('/addresses/new', extra: payload);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(children: [
        // ---- Map fills the whole background ----
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: _centre, initialZoom: 16,
            // Latitude clamp — OSM tiles get weird near the poles; cap to Web Mercator's safe range.
            cameraConstraint: CameraConstraint.contain(
                bounds: LatLngBounds(const LatLng(-85, -180), const LatLng(85, 180))),
            onMapEvent: _onMapEvent,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'uz.goshtli.app',
              maxZoom: 19,
              // Subdomains spec for OSM is just the default tile server; keeping empty avoids deprecation warnings.
            ),
          ],
        ),

        // ---- Centre marker — drawn over the map at screen-centre, independent of map movement ----
        IgnorePointer(child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // The shadow under the marker keeps a sense of depth as the map slides beneath it
            Container(width: 56, height: 56, alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: cs.onSurface,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 4))]),
              child: Icon(Icons.home_rounded, color: cs.surface, size: 28)),
            // Tiny "pin tail" pointing down to the exact coordinate
            Container(width: 2, height: 8, color: cs.onSurface),
          ]))),

        // ---- Top app bar — translucent back button + search affordance (search not wired yet) ----
        SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(children: [
            Material(color: cs.surface, shape: const CircleBorder(),
              child: InkResponse(onTap: () => context.pop(), radius: 24,
                child: const Padding(padding: EdgeInsets.all(10),
                  child: Icon(Icons.arrow_back_rounded)))),
            const Spacer(),
          ]))),

        // ---- "My location" FAB on the right side ----
        Positioned(right: 16, bottom: 220,
          child: Material(color: cs.surface, shape: const CircleBorder(),
            elevation: 4,
            child: InkResponse(onTap: _goToMyLocation, radius: 28,
              child: Padding(padding: const EdgeInsets.all(12),
                child: Icon(Icons.near_me_rounded, color: cs.primary))))),

        // ---- Bottom confirmation card — title, resolved address, CTA ----
        Positioned(left: 0, right: 0, bottom: 0,
          child: SafeArea(top: false, child: Container(
            decoration: BoxDecoration(color: cs.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22))),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // "Hammasi to'g'rimi?" header
              Text(t.addressMapConfirmTitle,
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(t.addressMapConfirmBody,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              // Resolved address text — shows the matched street name as the pin moves. Tiny spinner when resolving.
              Row(children: [
                if (_resolving) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                else Icon(Icons.location_on_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(_resolvedAddress.isEmpty ? '…' : _resolvedAddress,
                  style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 2, overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 14),
              SizedBox(width: double.infinity, height: 52, child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: cs.primary, foregroundColor: cs.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: _confirm,
                child: Text(t.addressMapConfirmCta,
                    style: tt.titleMedium?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w700)))),
            ])))),
      ]),
    );
  }
}
