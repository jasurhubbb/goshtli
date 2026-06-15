// Configured Dio instance — adds the bearer token to every request and auto-refreshes on 401 using a separate clean Dio instance.
//
// onAuthExpired is set AFTER construction by the auth provider wiring (see auth_providers.dart). This avoids a Riverpod
// type-inference cycle: ApiClient must not statically depend on AuthNotifier, even though it calls back into it at runtime.
import 'package:dio/dio.dart';

import '../auth/token_storage.dart';
import '../config/env.dart';


class ApiClient {
  final Dio dio;                     // for normal API calls — has the auth interceptor attached
  final Dio _refreshDio;             // bare Dio used only to call /auth/refresh — avoids the auth interceptor recursing
  final TokenStorage _tokens;
  void Function()? onAuthExpired;    // post-construction hook; left null until auth_providers wires it in

  ApiClient({required TokenStorage tokens})
      : _tokens = tokens, dio = Dio(_baseOptions()), _refreshDio = Dio(_baseOptions()) {
    // Request interceptor — attach Authorization header from secure storage if a token exists
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final t = await _tokens.readAccess();
        if (t != null) options.headers['Authorization'] = 'Bearer $t';
        handler.next(options);
      },
      // Response interceptor — `validateStatus < 500` lets 401 through as a normal response (so callers
      // can inspect the body), but that ALSO bypassed the refresh hook below for years. Catch 401 here
      // too, refresh the token, and replay the request — so endpoints that check `statusCode == 200`
      // (like delivery_repository) don't surface "HTTP 401" to the user when the token simply expired.
      onResponse: (response, handler) async {
        final isAuthEndpoint = response.requestOptions.path.contains('/auth/');
        if (response.statusCode != 401 || isAuthEndpoint) return handler.next(response);
        final replayed = await _refreshAndReplay(response.requestOptions);
        if (replayed != null) return handler.resolve(replayed);
        return handler.next(response);
      },
      // Response interceptor — on 401 from any endpoint other than /auth itself, try refresh once and replay the request
      onError: (err, handler) async {
        final response = err.response;
        final isAuthEndpoint = err.requestOptions.path.contains('/auth/');
        if (response?.statusCode != 401 || isAuthEndpoint) return handler.next(err);
        final replayed = await _refreshAndReplay(err.requestOptions);
        if (replayed != null) return handler.resolve(replayed);
        return handler.next(err);
      },
    ));
  }

  /// Refresh the access token and replay the original request. Returns the retried Response on success,
  /// or null if refresh failed (in which case the caller should let the original 401 propagate so the UI
  /// can redirect to login). Shared by onResponse + onError since both can see a 401 depending on
  /// `validateStatus` and the Dio version.
  ///
  /// IMPORTANT: `_refreshDio` carries the same `validateStatus: < 500` as the main dio, so a refresh that
  /// returns 401 (revoked / expired refresh token) does NOT throw — it returns a Response with that
  /// status. We have to check `statusCode` explicitly; the previous version relied on `on DioException`
  /// which never fired, and the cast on `r.data['access']` silently failed because `r.data['access']`
  /// was null on the 401 error body.
  Future<Response?> _refreshAndReplay(RequestOptions original) async {
    final refresh = await _tokens.readRefresh();
    if (refresh == null) { onAuthExpired?.call(); return null; }
    try {
      final r = await _refreshDio.post('/auth/refresh/', data: {'refresh': refresh});
      // Treat anything other than 200 + a body containing both tokens as a refresh failure. This covers
      // 401 (revoked), 400 (malformed), and any future schema drift.
      final body = r.data;
      final access = body is Map ? body['access'] as String? : null;
      final newRefresh = body is Map ? body['refresh'] as String? : null;
      if (r.statusCode != 200 || access == null || newRefresh == null) {
        await _tokens.clear();
        onAuthExpired?.call();
        return null;
      }
      // Backend rotates refresh tokens (settings: ROTATE_REFRESH_TOKENS=True), so save both new ones.
      await _tokens.writeBoth(access: access, refresh: newRefresh);
      original.headers['Authorization'] = 'Bearer $access';
      return await dio.fetch(original);
    } catch (_) {
      // Network error / unexpected exception during refresh — clear and let the original 401 propagate.
      await _tokens.clear();
      onAuthExpired?.call();
      return null;
    }
  }

  static BaseOptions _baseOptions() => BaseOptions(
        baseUrl: Env.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
        // Don't auto-throw on 4xx — interceptors above need to inspect the response object
        validateStatus: (s) => s != null && s < 500,
      );
}
