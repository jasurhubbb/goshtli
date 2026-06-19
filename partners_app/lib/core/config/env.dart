/// Build-time environment for the partners app. Mirrors mobile/lib/core/config/env.dart.
/// Override with `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1`.
class Env {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://goshtli-production.up.railway.app/api/v1',
  );
}
