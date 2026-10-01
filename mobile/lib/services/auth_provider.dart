import 'package:flutter/material.dart';
import '../models/user.dart';
import 'api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get error => _error;

  Future<bool> checkAuth() async {
    if (!await _api.hasToken()) return false;
    try {
      final data = await _api.get('/auth/me');
      _user = User.fromJson(data);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) await _api.clearToken();
      return false;
    } catch (_) {
      // A temporary offline/API failure must not destroy a valid saved login.
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _api.post('/auth/login', body: {
        'email': email,
        'password': password,
      });
      await _api.saveToken(data['access_token']);
      final userData = await _api.get('/auth/me');
      _user = User.fromJson(userData);
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } on ApiNetworkException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String fullName, String username, String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _api.post('/auth/register', body: {
        'full_name': fullName,
        'username': username,
        'email': email,
        'password': password,
      });
      return await login(email, password);
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } on ApiNetworkException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _api.clearToken();
    _user = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
