// FCM bootstrap — initializes Firebase, requests permission (Android 13+ requires it), registers the device token
// with our backend, and handles taps so a notification can deep-link to the right screen.
//
// Lifecycle:
//   • app boot: initialize() runs from main.dart before runApp
//   • on login: registerCurrentToken() is called by AuthNotifier so the backend learns this user's device
//   • on logout: tokens stay on the device but the backend forgets them when the new user re-registers
//     (uses update_or_create on the token, re-claims for the new account)
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../network/api_client.dart';


/// Background message handler — must be a top-level function, not a closure or method.
/// Called when a push arrives while the app is terminated/background. We don't display anything custom here;
/// Android's system tray handles the visual notification automatically from the FCM payload.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // No-op for v2 — the system shows the notification; tap handling happens via FirebaseMessaging.onMessageOpenedApp
}


class FcmService {
  final ApiClient _api;
  FcmService(this._api);

  /// One-time init from main(). Idempotent — safe to call repeatedly.
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
    } catch (e) {
      // No google-services.json or Firebase project misconfigured → log + continue without push.
      // The app still works fully via in-app polling.
      debugPrint('Firebase init failed (push disabled): $e');
    }
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
      // Never propagate — push registration shouldn't break login
      debugPrint('Token registration failed: $e');
    }
  }
}
