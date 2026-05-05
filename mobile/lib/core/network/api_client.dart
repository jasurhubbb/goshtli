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
      // Response interceptor — on 401 from any endpoint other than /auth itself, try refresh once and replay the request
      onError: (err, handler) async {
        final response = err.response;
        final isAuthEndpoint = err.requestOptions.path.contains('/auth/');
        if (response?.statusCode != 401 || isAuthEndpoint) return handler.next(err);

        final refresh = await _tokens.readRefresh();
        if (refresh == null) { onAuthExpired?.call(); return handler.next(err); }

        try {
          final r = await _refreshDio.post('/auth/refresh/', data: {'refresh': refresh});
          // Backend rotates refresh tokens (settings: ROTATE_REFRESH_TOKENS=True), so save both new ones
          await _tokens.writeBoth(access: r.data['access'] as String, refresh: r.data['refresh'] as String);
          // Replay the original request with the new access token
          err.requestOptions.headers['Authorization'] = 'Bearer ${r.data['access']}';
          final retry = await dio.fetch(err.requestOptions);
          return handler.resolve(retry);
        } on DioException {
          // Refresh failed (token revoked, expired beyond refresh window) — clear and bubble up so UI redirects to login
          await _tokens.clear();
          onAuthExpired?.call();
          return handler.next(err);
        }
      },
    ));
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
