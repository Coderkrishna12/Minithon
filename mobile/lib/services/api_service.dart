import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static final Map<String, dynamic> _cache = {};
  String? _customBaseUrl;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _customBaseUrl = prefs.getString(ApiConstants.customBaseUrlKey);
  }

  String get baseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.trim().isNotEmpty) {
      return _customBaseUrl!.trim();
    }
    if (ApiConstants.configuredBaseUrl.isNotEmpty) {
      return ApiConstants.configuredBaseUrl;
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return ApiConstants.emulatorBaseUrl;
    }
    return ApiConstants.localBaseUrl;
  }

  Future<void> setCustomBaseUrl(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url == null || url.trim().isEmpty) {
      _customBaseUrl = null;
      await prefs.remove(ApiConstants.customBaseUrlKey);
    } else {
      String clean = url.trim();
      while (clean.endsWith('/')) {
        clean = clean.substring(0, clean.length - 1);
      }
      if (!clean.endsWith('/api')) {
        clean = '$clean/api';
      }
      _customBaseUrl = clean;
      await prefs.setString(ApiConstants.customBaseUrlKey, clean);
    }
    _cache.clear();
  }

  static String normalizeUrl(String input) {
    String clean = input.trim();
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
      clean = 'http://$clean';
    }
    if (!clean.endsWith('/api')) {
      clean = '$clean/api';
    }
    return clean;
  }

  Future<Map<String, dynamic>> testConnection([String? testUrl]) async {
    final target = (testUrl != null && testUrl.trim().isNotEmpty)
        ? normalizeUrl(testUrl)
        : baseUrl;
    try {
      final response = await http
          .get(Uri.parse('$target/health'))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'message': 'Connected successfully (${response.statusCode})'};
      }
      return {'success': false, 'message': 'Server responded with status ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'message': formatNetworkError(e, target)};
    }
  }

  static String formatNetworkError(dynamic e, String targetUrl) {
    final str = e.toString();
    if (str.contains('110') || str.contains('Connection timed out') || str.contains('TimeoutException')) {
      return 'Connection timed out at $targetUrl.\n\n'
          '• If using a physical phone, "10.0.2.2" will not connect. Connect phone and PC to the same Wi-Fi and use your PC\'s Wi-Fi IP (e.g. http://10.183.82.30:8000/api).\n'
          '• Or if connected via USB, run "adb reverse tcp:8000 tcp:8000" in your terminal and set server to http://localhost:8000/api.';
    }
    if (str.contains('Connection refused') || str.contains('errno = 111') || str.contains('errno = 61')) {
      return 'Connection refused at $targetUrl.\n\n'
          'Please ensure your FastAPI backend is running and listening on 0.0.0.0:\n'
          'uvicorn app.main:app --reload --host 0.0.0.0 --port 8000';
    }
    if (str.contains('SocketException') || str.contains('Failed host lookup')) {
      return 'Cannot reach $targetUrl.\n\nPlease check network connectivity and backend address.';
    }
    return str;
  }

  Future<T> _wrapNetworkCall<T>(Future<T> Function() call) async {
    try {
      return await call().timeout(const Duration(seconds: 12));
    } on TimeoutException {
      throw ApiNetworkException(
        formatNetworkError('TimeoutException: Connection timed out', baseUrl),
        url: baseUrl,
      );
    } catch (e) {
      if (e is ApiException || e is ApiNetworkException) rethrow;
      final str = e.toString();
      if (str.contains('SocketException') ||
          str.contains('Connection timed out') ||
          str.contains('Connection refused') ||
          str.contains('Failed host lookup') ||
          str.contains('ClientException')) {
        throw ApiNetworkException(
          formatNetworkError(e, baseUrl),
          url: baseUrl,
        );
      }
      rethrow;
    }
  }

  Future<String?> get _token async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(ApiConstants.tokenKey);
  }

  Future<Map<String, String>> get _headers async {
    final token = await _token;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> get(String path) async {
    try {
      return await _wrapNetworkCall(() async {
        final response = await http.get(
          Uri.parse('$baseUrl$path'),
          headers: await _headers,
        );
        final result = _handleResponse(response);
        _cache[path] = result;
        return result;
      });
    } catch (e) {
      if (_cache.containsKey(path)) {
        return _cache[path] as Map<String, dynamic>;
      }
      rethrow;
    }
  }

  Future<bool> get isOffline async {
    try {
      await http.get(
        Uri.parse('$baseUrl/health'),
        headers: await _headers,
      ).timeout(const Duration(seconds: 4));
      return false;
    } catch (_) {
      return true;
    }
  }

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body}) async {
    return _wrapNetworkCall(() async {
      final response = await http.post(
        Uri.parse('$baseUrl$path'),
        headers: await _headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response);
    });
  }

  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? body}) async {
    return _wrapNetworkCall(() async {
      final response = await http.put(
        Uri.parse('$baseUrl$path'),
        headers: await _headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response);
    });
  }

  Future<Map<String, dynamic>> patch(String path, {Map<String, dynamic>? body}) async {
    return _wrapNetworkCall(() async {
      final response = await http.patch(
        Uri.parse('$baseUrl$path'),
        headers: await _headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response);
    });
  }

  Future<Map<String, dynamic>> delete(String path) async {
    return _wrapNetworkCall(() async {
      final response = await http.delete(
        Uri.parse('$baseUrl$path'),
        headers: await _headers,
      );
      return _handleResponse(response);
    });
  }

  Future<List<dynamic>> getList(String path) async {
    return _wrapNetworkCall(() async {
      final response = await http.get(
        Uri.parse('$baseUrl$path'),
        headers: await _headers,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      throw ApiException(response.statusCode, response.body);
    });
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ApiConstants.tokenKey, token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ApiConstants.tokenKey);
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
