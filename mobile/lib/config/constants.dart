class ApiConstants {
  // Use 10.0.2.2 for Android emulator to reach host localhost
  // Use localhost for iOS simulator
  // Use your machine's IP for physical devices
  static const String baseUrl = 'http://10.0.2.2:8000/api';
  static const String webBaseUrl = 'http://localhost:8000/api';

  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
}
