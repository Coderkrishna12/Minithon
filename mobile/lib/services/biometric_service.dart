import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static const _channel = MethodChannel('privacyshield/biometric');
  static const _secureStorage = MethodChannel('privacyshield/secure_storage');
  static const _enabledKey = 'biometric_app_lock_enabled';
  static const _loginEmailKey = 'biometric_login_email';
  static const _loginPasswordKey = 'biometric_login_password';

  /// Native biometric prompt and keystore storage exist only on Android and iOS.
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

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

  /// Email saved for fingerprint sign-in, or null when none is saved.
  Future<String?> get savedLoginEmail async {
    if (!supported) return null;
    try {
      return await _secureStorage.invokeMethod<String>('read', {'key': _loginEmailKey});
    } on PlatformException {
      return null;
    }
  }

  /// Saves credentials encrypted with the platform keystore. Only read back after [authenticate].
  Future<void> saveLogin(String email, String password) async {
    await _secureStorage.invokeMethod<void>('write', {'key': _loginEmailKey, 'value': email});
    await _secureStorage.invokeMethod<void>('write', {'key': _loginPasswordKey, 'value': password});
  }

  /// Asks for the fingerprint, then returns the saved (email, password), or null if cancelled.
  Future<(String, String)?> unlockLogin() async {
    if (!await authenticate()) return null;
    final email = await _secureStorage.invokeMethod<String>('read', {'key': _loginEmailKey});
    final password = await _secureStorage.invokeMethod<String>('read', {'key': _loginPasswordKey});
    if (email == null || password == null) return null;
    return (email, password);
  }

  Future<void> clearLogin() async {
    await _secureStorage.invokeMethod<void>('delete', {'key': _loginEmailKey});
    await _secureStorage.invokeMethod<void>('delete', {'key': _loginPasswordKey});
  }

  /// Confirms the fingerprint, then saves [email]/[password] for fingerprint sign-in.
  Future<void> enableLogin(BuildContext context, String email, String password) async {
    if (!supported) return;
    try {
      if (await authenticate()) {
        await saveLogin(email, password);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fingerprint sign-in enabled.')),
          );
        }
      }
    } on PlatformException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Fingerprint sign-in is unavailable.')),
        );
      }
    }
  }

  /// After a password sign-in, offers to enable fingerprint sign-in for this account.
  Future<void> offerLogin(BuildContext context, String email, String password) async {
    if (!supported || await savedLoginEmail == email) return;
    if (!context.mounted) return;
    final accept = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.fingerprint, size: 40),
        title: const Text('Sign in with fingerprint?'),
        content: const Text(
          'Next time, sign in with your fingerprint or screen lock instead of typing your email and password.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enable')),
        ],
      ),
    );
    if (accept == true && context.mounted) await enableLogin(context, email, password);
  }
}
