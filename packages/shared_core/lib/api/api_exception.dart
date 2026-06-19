/// Domain exception mirrored across buyer + partner apps. Repositories normalize Dio errors + DRF
/// response shapes into this so screens render a friendly message regardless of source.
class ApiException implements Exception {
  /// Human-readable summary the UI surfaces. Already localized by the backend when possible
  /// (`detail` field on most error responses).
  final String message;

  /// Field-level errors when the backend returned a DRF {field: [msg, ...]} body. Empty when the error
  /// was a single `detail` line.
  final Map<String, List<String>> fieldErrors;

  ApiException(this.message, [this.fieldErrors = const {}]);

  @override
  String toString() => 'ApiException($message)';
}
