// AdminApiClient — separate Dio instance for the admin page. Reads the Authorization header from
// AdminTokenStorage (not the main app's TokenStorage), so admin API calls are completely independent of
// whatever user is logged into the main app.
//
// Differences from the main ApiClient:
//   • No refresh-on-401 retry — if admin tokens go stale, we surface the 401 to the AdminAuthNotifier
//     which flips back to "locked" and prompts the password dialog again. Simpler than maintaining a
//     parallel refresh interceptor for a low-frequency path.
//   • No onAuthExpired callback wiring — main auth is not involved.
import 'package:dio/dio.dart';

import '../../../core/config/env.dart';
import 'admin_token_storage.dart';


class AdminApiClient {
  final Dio dio;
  final AdminTokenStorage _tokens;
  /// Optional hook invoked when admin API returns 401 (token expired / cleared). AdminAuthNotifier wires
  /// this to its own lock() method so a stale admin session is detected the next time admin opens the page.
  void Function()? onAdminAuthExpired;

  AdminApiClient({required AdminTokenStorage tokens}) : _tokens = tokens, dio = Dio(_baseOptions()) {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final t = await _tokens.readAccess();
        if (t != null) options.headers['Authorization'] = 'Bearer $t';
        handler.next(options);
      },
      onError: (err, handler) async {
        // 401 on any admin-side request means the admin JWT is no longer valid — invalidate the local
        // admin session and let the UI re-prompt for the password. We don't try to refresh here because
        // admin sessions are short-lived by design.
        if (err.response?.statusCode == 401) {
          await _tokens.clear();
          onAdminAuthExpired?.call();
        }
        handler.next(err);
      },
    ));
  }

  static BaseOptions _baseOptions() => BaseOptions(
        baseUrl: Env.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),       // admin uploads photos — give the receive side more headroom
        headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
        validateStatus: (s) => s != null && s < 500,
      );
}
