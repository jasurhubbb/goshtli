// LocationService — wraps geolocator with our own permission flow + persistence.
//
// v3 product pivot: app boots anonymous, asks for location once during onboarding. Result is cached in
// SharedPreferences so subsequent launches go straight to home. User can decline — app still works, just no
// "near me" sorting.
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';


/// Latitude / longitude pair. Doubles instead of a separate class to keep things flat.
typedef LatLng = ({double lat, double lng});


class LocationService {
  // Keys used in SharedPreferences. Prefixed so they don't collide with other app prefs.
  static const _kOnboardingDone = 'loc.onboarding_done';
  static const _kLat = 'loc.lat';
  static const _kLng = 'loc.lng';

  /// Has the user been through the location onboarding flow (granted OR explicitly skipped)?
  Future<bool> onboardingDone() async =>
      (await SharedPreferences.getInstance()).getBool(_kOnboardingDone) ?? false;

  Future<void> markOnboardingDone() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kOnboardingDone, true);
  }

  /// Read the cached location — null if user skipped or never granted permission.
  Future<LatLng?> cached() async {
    final p = await SharedPreferences.getInstance();
    final lat = p.getDouble(_kLat); final lng = p.getDouble(_kLng);
    return (lat == null || lng == null) ? null : (lat: lat, lng: lng);
  }

  /// Full request flow: prompt for permission → fetch current position → cache it.
  /// Returns the position on success, null if user declined or device couldn't get a fix.
  Future<LatLng?> requestAndFetch() async {
    try {
      // Check current permission state without prompting
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return null;

      // Coarse-only timeout — don't make the user wait forever on a slow GPS lock
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low,
                                                  timeLimit: Duration(seconds: 6)));
      final result = (lat: pos.latitude, lng: pos.longitude);
      final p = await SharedPreferences.getInstance();
      await p.setDouble(_kLat, result.lat);
      await p.setDouble(_kLng, result.lng);
      return result;
    } catch (_) {
      // Any failure (timeout, no GPS, user cancelled) → just return null. Caller falls back to no-location UX.
      return null;
    }
  }
}
