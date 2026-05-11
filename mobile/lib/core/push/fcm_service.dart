// FCM bootstrap — Firebase init, OS permission, FCM token registration with backend, deep-link tap handling.
//
// Lifecycle:
//   • app boot: initialize() runs from main.dart before runApp (sets up the background handler)
//   • after first router builds: bindRouter() attaches tap listeners that navigate via go_router
//   • on login: registerCurrentToken() pushes the FCM token to backend so events route to the right user
//   • on logout: tokens stay on device; backend update_or_create re-binds them at next login
//
// Tap handling covers three states:
//   1. App in foreground  → push arrives → onMessage listener (currently silent; in-app polling refreshes UI)
//   2. App in background  → user taps the system tray notification → onMessageOpenedApp listener → navigate
//   3. App terminated    → user taps the system tray notification → getInitialMessage() on next launch → navigate
//
// Each push payload carries data['link'] (e.g. "/orders/5"). We feed that path to go_router's push().
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../network/api_client.dart';


/// Background message handler — MUST be a top-level function with @pragma('vm:entry-point') so the Dart VM can
/// reach it after the app has been killed. Currently a no-op (system tray handles display); reserved here for
/// future custom-payload work like local-notification grouping.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // No-op for v2 — visual is handled by Android's notification system from the FCM payload.
}


class FcmService {
  final ApiClient _api;
  GoRouter? _router;
  bool _listenersAttached = false;

  FcmService(this._api);

  /// One-time init from main(). Tries to initialize Firebase + register the background handler.
  /// If google-services.json is missing or Firebase misconfigured, fails silently — push disabled, rest of app still works.
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
    } catch (e) {
      debugPrint('Firebase init failed (push disabled): $e');
    }
  }

  /// Called from MeatMarketplaceApp's build once the router is constructed. Idempotent — re-calls just update the
  /// router pointer (cheap), but the listener subscription only fires once.
  void bindRouter(GoRouter router) {
    _router = router;
    if (!_listenersAttached) {
      _listenersAttached = true;
      _attachListeners();
    }
  }

  /// Wire up three notification-tap entry points. Foreground stays silent for now.
  Future<void> _attachListeners() async {
    try {
      // Foreground arrival — placeholder. Could show a SnackBar if we plumb in a ScaffoldMessenger key later.
      FirebaseMessaging.onMessage.listen((m) => debugPrint('FCM foreground: ${m.notification?.title}'));

      // Background → user taps the system tray notification → app comes to foreground here
      FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

      // Terminated → user taps the notification → app cold-starts → check for the message that launched it
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _handleTap(initial);
    } catch (e) {
      debugPrint('FCM listener attach failed: $e');
    }
  }

  void _handleTap(RemoteMessage message) {
    // Backend sends a path string in data['link'] (e.g. "/orders/5", "/listings/new", "/chats/3").
    // Feed it directly to go_router. Empty/missing → ignore (notification was informational only).
    final link = (message.data['link'] as String?)?.trim() ?? '';
    if (link.isEmpty || _router == null) return;
    try { _router!.push(link); }
    catch (e) { debugPrint('Deep-link push failed for "$link": $e'); }
  }

  /// Ask the OS for permission (Android 13+, iOS). Returns true if granted. Safe to call repeatedly.
  Future<bool> requestPermission() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true, badge: true, sound: true);
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
             settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      debugPrint('Permission request failed: $e');
      return false;
    }
  }

  /// Pull the current FCM token + POST to /notifications/register-device/. Called after login so the backend
  /// knows which user owns this device. Idempotent — backend's update_or_create handles repeat calls.
  Future<void> registerCurrentToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _api.dio.post('/notifications/register-device/',
          data: {'token': token, 'platform': 'ANDROID'});
    } catch (e) {
      debugPrint('Token registration failed: $e');
    }
  }
}
