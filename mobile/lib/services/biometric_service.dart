import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static const _channel = MethodChannel('privacyshield/biometric');
  static const _enabledKey = 'biometric_app_lock_enabled';

  Future<bool> get enabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<bool> authenticate() async =>
      await _channel.invokeMethod<bool>('authenticate') ?? false;

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }
}
