/// Backend base URL — the same backend, database and admin as the customer app
/// and the website. Override with --dart-define=API_HOST=... for testing.
class ApiConfig {
  static const String host = String.fromEnvironment(
    'API_HOST',
    defaultValue: 'https://app.dyspatch.com.ng/backend',
  );
  static const String baseUrl = '$host/api';
  static const Duration timeout = Duration(seconds: 25);
}
