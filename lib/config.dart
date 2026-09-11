/// App-wide configuration.
///
/// The hosted PharmaTrack backend can be overridden at build/run time:
///     flutter run --dart-define=API_BASE_URL=https://yourhost.onrender.com
class ApiConfig {
  ApiConfig._();

  /// Scheme + host of the PharmaTrack backend (no trailing slash). The
  /// default is the Render deployment; tests and local dev override it.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://pharmatrack-efsq.onrender.com',
  );

  /// Base of the versioned JSON API.
  static String get apiBase => '$baseUrl/api/v1';
}