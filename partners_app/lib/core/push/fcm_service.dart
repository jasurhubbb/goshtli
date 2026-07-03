// FCM bootstrap for the partner app — Firebase init, permission, token registration, foreground
// live-refresh, deep-link tap handling.
//
// Production-quality real-time updates (v3.9.12):
//   • Foreground FCM arrival → parse data['kind'] → invalidate the matching Riverpod providers so
//     the UI live-updates (Buyurtmalar count, chat unread badge, notifications feed) WITHOUT the
//     user pulling to refresh. Mirrors WhatsApp/Telegram behavior where new messages just appear.
//   • Also emits a broadcast stream of raw RemoteMessage-data maps so screens that need to react
//     locally (e.g. Chatlar list) can `ref.listen()` and refresh themselves.
//   • In-app banner (SnackBar via a global scaffoldMessengerKey) fires for messages that aren't
//     already visible on-screen — you don't want to double-notify the user for a chat they're
//     currently reading.
//
// Data payload contract (populated by backend apps/notifications/fcm.py.send_to_user):
//   data: {
//     "kind": "ORDER_PLACED" | "ORDER_STATUS_CHANGED" | "ORDER_CANCELLED" | "CHAT_MESSAGE" | ...,
//     "link": "/orders/42" | "/chats/7" | ...,
//     "order_id":        "42"           (when applicable)
//     "conversation_id": "7"            (chat messages)
//     "sender_id":       "12"           (chat messages)
//     "status":          "PROCESSING"   (order status changes)
//   }
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../network/providers.dart';
import '../../features/chats/chats_list_screen.dart' show partnerUnreadChatsTotalProvider,
    partnerConversationsProvider;
import '../../features/orders_inbox/inbox_providers.dart' show inboxProvider;
import '../../features/dashboard/dashboard_providers.dart' show dashboardProvider;


/// Background message handler — MUST be a top-level function with `@pragma('vm:entry-point')`. Runs
/// in a separate isolate, so no access to app state / Riverpod. System tray notification is shown
/// automatically by FCM; this callback stays a no-op.
@pragma('vm:entry-point')
Future<void> partnerFirebaseBackgroundHandler(RemoteMessage message) async {
  // No-op — Android/iOS show the notification. Live refresh happens on next foreground.
}


class PartnerFcmService {
  final Ref _ref;
  GoRouter? _router;
  bool _listenersAttached = false;

  // Global key so we can pop SnackBars from an isolate/callback with no BuildContext.
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  final _eventsController = StreamController<Map<String, String>>.broadcast();

  /// Stream of raw FCM data payloads. Screens that need custom reactions (e.g. auto-scroll a
  /// chat when a new message lands in the SAME conversation they're viewing) can listen here.
  Stream<Map<String, String>> get events => _eventsController.stream;

  PartnerFcmService(this._ref);

  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(partnerFirebaseBackgroundHandler);
    } catch (e) {
      debugPrint('Firebase init failed (partner push disabled): $e');
    }
  }

  void bindRouter(GoRouter router) {
    _router = router;
    if (!_listenersAttached) {
      _listenersAttached = true;
      _attachListeners();
    }
  }

  Future<void> _attachListeners() async {
    try {
      // ---- Foreground: the WHOLE POINT of production-grade real-time UX. We invalidate providers
      // + emit to the event stream + show an in-app banner.
      FirebaseMessaging.onMessage.listen(_handleForeground);

      // ---- Background tap → app comes to foreground → we may want to refresh + navigate.
      FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

      // ---- Cold start via notification tap.
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _handleTap(initial);
    } catch (e) {
      debugPrint('Partner FCM listener attach failed: $e');
    }
  }

  void _handleForeground(RemoteMessage message) {
    final data = _stringifyData(message.data);
    _eventsController.add(data);
    _invalidateProviders(data);
    _showInAppBanner(message);
  }

  /// Kind → provider mapping. This is the "production-quality live update" — Buyurtmalar tab, chat
  /// unread badge, dashboard counts all react to the FCM the moment it arrives.
  void _invalidateProviders(Map<String, String> data) {
    final kind = data['kind'] ?? '';
    try {
      switch (kind) {
        case 'ORDER_PLACED':
          // New order landed on this supplier/qassob — refresh the "Yangi" bucket + dashboard KPI.
          _ref.invalidate(inboxProvider('new'));
          _ref.invalidate(dashboardProvider);
        case 'ORDER_STATUS_CHANGED':
        case 'ORDER_CANCELLED':
          // A pre-existing order's state moved — all three buckets could be affected (accept
          // pushes it new→active, deliver pushes active→done). Invalidate all three cheaply.
          _ref.invalidate(inboxProvider('new'));
          _ref.invalidate(inboxProvider('active'));
          _ref.invalidate(inboxProvider('done'));
          _ref.invalidate(dashboardProvider);
        case 'CHAT_MESSAGE':
          // Refresh unread badge + conversation list (last-message preview + unread count).
          _ref.invalidate(partnerUnreadChatsTotalProvider);
          _ref.invalidate(partnerConversationsProvider);
        default:
          // Unknown kind — refresh the dashboard as a safe fallback.
          _ref.invalidate(dashboardProvider);
      }
    } catch (e) {
      debugPrint('Partner FCM provider invalidation failed for kind=$kind: $e');
    }
  }

  /// In-app banner — WhatsApp/Telegram style. Uses a global ScaffoldMessengerKey so it works from
  /// any screen without needing a BuildContext parameter. Suppresses the banner when the user is
  /// already on the target screen (no point notifying about a chat they're actively viewing).
  void _showInAppBanner(RemoteMessage message) {
    final title = message.notification?.title ?? '';
    final body = message.notification?.body ?? '';
    if (title.isEmpty && body.isEmpty) return;
    final messenger = messengerKey.currentState;
    if (messenger == null) return;
    // Suppress if the user is already on the exact deep-link destination.
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
    // Same live-refresh we do on foreground — user might have missed several pushes while
    // backgrounded; UI must be fresh when it opens.
    _invalidateProviders(_stringifyData(message.data));
    final link = message.data['link']?.toString().trim() ?? '';
    if (link.isEmpty || _router == null) return;
    try { _router!.push(link); }
    catch (e) { debugPrint('Deep-link push failed for "$link": $e'); }
  }

  /// FCM data values arrive as `Object` (usually String). Cast defensively so consumers can rely
  /// on Map<String, String>.
  Map<String, String> _stringifyData(Map<String, dynamic> data) => {
        for (final e in data.entries) e.key: e.value?.toString() ?? '',
      };

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

  Future<void> registerCurrentToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _ref.read(apiClientProvider).dio.post('/notifications/register-device/',
          data: {'token': token, 'platform': 'ANDROID'});
    } catch (e) {
      debugPrint('Token registration failed: $e');
    }
  }
}


/// Provider for the FCM service — instantiated after ProviderScope so it can `ref.invalidate()`.
final partnerFcmServiceProvider = Provider<PartnerFcmService>((ref) =>
    PartnerFcmService(ref));
