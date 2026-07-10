import 'package:dio/dio.dart';

import '../auth/token_storage.dart';

/// Configured Dio instance shared between buyer + partner apps.
///
/// Behavior:
///   - Attaches `Authorization: Bearer <access_token>` from TokenStorage on every request.
///   - On 401 (including 401 returned with `validateStatus < 500`), tries to refresh with the stored
///     refresh token and replays the original request.
///   - Wipes tokens + calls `onAuthExpired` ONLY on a confirmed 401/403 from refresh. Network errors,
///     5xx, parse errors leave tokens on disk so cold-start retry can recover.
///
/// `onAuthExpired` is set AFTER construction by the host app's auth wiring (avoids cycles).
class ApiClient {
  final Dio dio;
  final Dio _refreshDio;
  final TokenStorage _tokens;
  void Function()? onAuthExpired;

  ApiClient({required TokenStorage tokens, required String baseUrl})
      : _tokens = tokens,
        dio = Dio(_baseOptions(baseUrl)),
        _refreshDio = Dio(_baseOptions(baseUrl)) {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Anonymous auth endpoints MUST go out without a Bearer header. DRF's JWTAuthentication runs
        // before AllowAny, so a stale token from a prior session on one of these would be rejected with
        // simplejwt's "Given token not valid for any token type" before the AllowAny view even ran.
        // v3.9.16 — phone-password-login (partner credential login) identifies the user by phone+password
        // and refresh carries its own token in the body; neither wants the stored access token.
        final path = options.path;
        final isAnonAuth = path.contains('/auth/phone-password-login')
                        || path.contains('/auth/refresh');
        if (!isAnonAuth) {
          final t = await _tokens.readAccess();
          if (t != null) options.headers['Authorization'] = 'Bearer $t';
        }
        handler.next(options);
      },
      onResponse: (response, handler) async {
        final isAuthEndpoint = response.requestOptions.path.contains('/auth/');
        if (response.statusCode != 401 || isAuthEndpoint) return handler.next(response);
        final replayed = await _refreshAndReplay(response.requestOptions);
        if (replayed != null) return handler.resolve(replayed);
        return handler.next(response);
      },
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

  Future<Response?> _refreshAndReplay(RequestOptions original) async {
    final refresh = await _tokens.readRefresh();
    if (refresh == null) { onAuthExpired?.call(); return null; }
    try {
      final r = await _refreshDio.post('/auth/refresh/', data: {'refresh': refresh});
      final body = r.data;
      final access = body is Map ? body['access'] as String? : null;
      final newRefresh = body is Map ? body['refresh'] as String? : null;
      if (r.statusCode == 200 && access != null && newRefresh != null) {
        await _tokens.writeBoth(access: access, refresh: newRefresh);
        original.headers['Authorization'] = 'Bearer $access';
        return await dio.fetch(original);
      }
      // Only WIPE tokens on a definitive auth failure (401/403). 5xx + others leave them on disk.
      if (r.statusCode == 401 || r.statusCode == 403) {
        await _tokens.clear();
        onAuthExpired?.call();
      }
      return null;
    } catch (_) {
      // Network blip during refresh — do NOT clear tokens. Next user-initiated request will retry.
      return null;
    }
  }

  static BaseOptions _baseOptions(String baseUrl) => BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
        validateStatus: (s) => s != null && s < 500,
      );
}
