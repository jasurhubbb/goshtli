// Build-time environment constants — never hardcode URLs in feature code; reference Env.apiBaseUrl instead.
class Env {
  // Default points to the Railway production backend so APKs built without --dart-define just work for testers.
  // For local dev override: flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
  // (Android emulator uses 10.0.2.2 instead of 127.0.0.1 to reach the host's localhost.)
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://goshtli-production.up.railway.app/api/v1',
  );
}
