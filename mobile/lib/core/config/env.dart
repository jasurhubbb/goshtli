// Build-time environment constants — never hardcode URLs in feature code; reference Env.apiBaseUrl instead.
class Env {
  // Override at build time: flutter run --dart-define=API_BASE_URL=https://api.prod.example.com/api/v1
  // Default points to localhost for iOS simulator; Android emulator uses 10.0.2.2 to reach host's localhost
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/api/v1',
  );
}
