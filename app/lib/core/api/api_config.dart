/// Backend base URL. Change here only (or pass --dart-define=API_BASE=...).
class ApiConfig {
  static const String host = String.fromEnvironment(
    'API_HOST',
    defaultValue: 'https://dyspatch.bitprofil.com',
  );
  static const String baseUrl = '$host/api';
  static const Duration timeout = Duration(seconds: 25);
}
