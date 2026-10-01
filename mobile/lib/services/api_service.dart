import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import 'server_discovery.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static final Map<String, dynamic> _cache = {};
  static final Map<String, List<dynamic>> _listCache = {};
  static const _secureStorage = MethodChannel('privacyshield/secure_storage');

  String get baseUrl => ServerDiscovery.baseUrl;

  /// Checks that a PrivacyShield server answers at [url] (a bare IP or an https tunnel address is fine).
  Future<Map<String, dynamic>> testConnection(String url) async {
    final base = ServerDiscovery.normalize(url);
    final ok = await ServerDiscovery.probe(base, timeout: const Duration(seconds: 5));
    return {
      'success': ok,
      'message': ok
          ? 'Connected to PrivacyShield at $base'
          : "No PrivacyShield server answered at $base. Open $base/health in the phone's browser; "
              "if that fails too, run 'python run.py --public' on the PC and use the https address it prints.",
    };
  }

  /// Saves [url] as the server to use; null or empty goes back to automatic discovery.
  Future<void> setCustomBaseUrl(String? url) async {
    if (url == null || url.trim().isEmpty) {
      await ServerDiscovery.clear();
      await ServerDiscovery.discover(includeSaved: false);
      return;
    }
    await ServerDiscovery.use(ServerDiscovery.normalize(url));
  }

  Future<String?> get _token async {
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
      return _secureStorage.invokeMethod<String>('read', {'key': ApiConstants.tokenKey});
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(ApiConstants.tokenKey);
  }

  Future<String?> get accessToken => _token;

  Future<Map<String, String>> get _headers async {
    final token = await _token;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> get(String path) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl$path'), headers: await _headers)
          .timeout(const Duration(seconds: 12));
      final result = _handleResponse(response);
      _cache[path] = result;
      return result;
    } catch (e) {
      if (e is ApiException) rethrow;
      if (_cache.containsKey(path)) {
        return _cache[path] as Map<String, dynamic>;
      }
      rethrow;
    }
  }

  Future<bool> get isOffline async {
    try {
      await http
          .get(Uri.parse('$baseUrl/health'), headers: await _headers)
          .timeout(const Duration(seconds: 5));
      return false;
    } catch (_) {
      return true;
    }
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: await _headers,
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(const Duration(seconds: 20));
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl$path'),
          headers: await _headers,
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(const Duration(seconds: 20));
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await http
        .patch(
          Uri.parse('$baseUrl$path'),
          headers: await _headers,
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(const Duration(seconds: 20));
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final response = await http
        .delete(Uri.parse('$baseUrl$path'), headers: await _headers)
        .timeout(const Duration(seconds: 20));
    return _handleResponse(response);
  }

  Future<List<dynamic>> getList(String path) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl$path'), headers: await _headers)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as List<dynamic>;
        _listCache[path] = data;
        return data;
      }
      throw ApiException(response.statusCode, response.body);
    } catch (e) {
      if (e is ApiException) rethrow;
      if (_listCache.containsKey(path)) return _listCache[path]!;
      rethrow;
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'data': decoded};
    }
    throw ApiException(response.statusCode, response.body);
  }

  Future<void> saveToken(String token) async {
    _cache.clear();
    _listCache.clear();
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
      await _secureStorage.invokeMethod<void>('write', {'key': ApiConstants.tokenKey, 'value': token});
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(ApiConstants.tokenKey, token);
    }
  }

  Future<void> clearToken() async {
    _cache.clear();
    _listCache.clear();
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
      await _secureStorage.invokeMethod<void>('delete', {'key': ApiConstants.tokenKey});
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(ApiConstants.tokenKey);
    }
  }

  Future<bool> hasToken() async {
    final token = await _token;
    return token != null && token.isNotEmpty;
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String body;

  ApiException(this.statusCode, this.body);

  String get message {
    try {
      final json = jsonDecode(body);
      return json['detail'] ?? 'Request failed';
    } catch (_) {
      return body.isNotEmpty ? body : 'Request failed with status $statusCode';
    }
  }

  @override
  String toString() => message;
}

class ApiNetworkException implements Exception {
  final String message;
  final String? url;

  ApiNetworkException(this.message, {this.url});

  @override
  String toString() => message;
}
