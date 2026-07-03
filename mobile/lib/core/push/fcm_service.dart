// FCM bootstrap — Firebase init, permission, token registration, foreground live-refresh, deep-link
// tap handling.
//
// v3.9.12 production-quality real-time updates:
//   • Foreground FCM arrival → parse data['kind'] → invalidate the matching Riverpod providers so
//     the UI live-updates (Buyurtmalar, chat unread badge, notifications) WITHOUT a pull-to-refresh
//     — Telegram/WhatsApp behavior where new messages just appear on-screen.
//   • In-app banner (SnackBar via a global scaffoldMessengerKey) fires for pushes whose deep-link
//     destination isn't the currently-visible screen.
//
// Data payload contract (from backend apps/notifications/fcm.py.send_to_user):
//   {kind: "ORDER_PLACED"|"ORDER_STATUS_CHANGED"|"CHAT_MESSAGE"|..., link: "/orders/5",
//    order_id: "5", conversation_id: "7", ...}
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../network/api_client.dart';
import '../../features/chats/providers/chats_providers.dart';
import '../../features/orders/providers/orders_providers.dart';


/// Background message handler — MUST be a top-level function with @pragma('vm:entry-point') so the Dart VM can
/// reach it after the app has been killed. Currently a no-op (system tray handles display); reserved here for
/// future custom-payload work like local-notification grouping.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // No-op for v2 — visual is handled by Android's notification system from the FCM payload.
}


class FcmService {
  final ApiClient _api;
  Ref? _ref;
  GoRouter? _router;
  bool _listenersAttached = false;

  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  FcmService(this._api, {Ref? ref}) : _ref = ref;

  /// Late-bind the Riverpod Ref after ProviderScope has spun up. Must be called from the app root
  /// before FCM listeners actually deliver messages (otherwise foreground pushes can't invalidate).
  set ref(Ref ref) => _ref = ref;

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

  /// Wire up three notification-tap entry points + foreground live-refresh (v3.9.12).
  Future<void> _attachListeners() async {
    try {
      // Foreground: live-refresh + in-app banner. This is what turns FCM from "tap to jump" into
      // real-time messenger behavior — new orders appear in the tab, chat badge updates, etc.
      FirebaseMessaging.onMessage.listen(_handleForeground);

      // Background → user taps the system tray notification → app comes to foreground here
      FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

      // Terminated → user taps the notification → app cold-starts → check for the message that launched it
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _handleTap(initial);
    } catch (e) {
      debugPrint('FCM listener attach failed: $e');
    }
  }

  void _handleForeground(RemoteMessage message) {
    _invalidateProviders(message);
    _showInAppBanner(message);
  }

  /// Route by `data['kind']` (populated by backend v3.9.12) to the buyer-side providers so the UI
  /// re-fetches the moment the FCM lands. Falls back safely when the kind is unknown.
  void _invalidateProviders(RemoteMessage message) {
    final ref = _ref;
    if (ref == null) return;
    final kind = message.data['kind']?.toString() ?? '';
    try {
      switch (kind) {
        case 'ORDER_PLACED':
        case 'ORDER_STATUS_CHANGED':
        case 'ORDER_CANCELLED':
          // Buyer's orders list — status just moved on one of their orders.
          ref.invalidate(myOrdersProvider);
        case 'CHAT_MESSAGE':
          // Unread badge on the home AppBar chat icon + conversations list.
          ref.invalidate(unreadChatsTotalProvider);
          ref.invalidate(conversationsProvider);
        default:
          // Unknown → refresh the two most-visible surfaces so the user's next glance is fresh.
          ref.invalidate(myOrdersProvider);
      }
    } catch (e) {
      debugPrint('FCM provider invalidation failed for kind=$kind: $e');
    }
  }

  /// Telegram-style in-app banner. Suppressed when the user is already viewing the destination
  /// (no point notifying about a chat they're actively reading).
  void _showInAppBanner(RemoteMessage message) {
    final title = message.notification?.title ?? '';
    final body = message.notification?.body ?? '';
    if (title.isEmpty && body.isEmpty) return;
    final messenger = messengerKey.currentState;
    if (messenger == null) return;
    final link = message.data['link']?.toString() ?? '';
    if (link.isNotEmpty && _router?.state.matchedLocation == link) return;
    messenger.showSnackBar(SnackBar(
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) Text(title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(body, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13)),
          ],
        ]),
      action: link.isEmpty ? null : SnackBarAction(label: "OCH",
          onPressed: () { try { _router?.push(link); } catch (_) {} }),
    ));
  }

  void _handleTap(RemoteMessage message) {
    // Same live-refresh we do on foreground — user may have missed several pushes while away.
    _invalidateProviders(message);
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
