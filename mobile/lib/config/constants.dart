class ApiConstants {
  // Set with --dart-define=API_BASE_URL=https://your-host/api (required on a physical device).
  static const String configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
  // 10.0.2.2 is how the Android emulator reaches the host machine's localhost.
  static const String emulatorBaseUrl = 'http://10.0.2.2:8000/api';
  static const String localBaseUrl = 'http://localhost:8000/api';

  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String customBaseUrlKey = 'custom_api_base_url';
}

