import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../services/auth_provider.dart';

import '../services/biometric_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _biometricService = BiometricService();
  bool _obscurePassword = true;
  bool _isAuthenticatingBiometric = false;

  @override
  void initState() {
    super.initState();
    _checkSavedBiometrics();
  }

  Future<void> _checkSavedBiometrics() async {
    final creds = await _biometricService.getSavedCredentials();
    if (creds['email'] != null && mounted) {
      _emailCtrl.text = creds['email']!;
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final success = await auth.login(email, password);
    if (success && mounted) {
      await _biometricService.saveBiometricCredentials(email, password);
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  Future<void> _handleBiometricAuth() async {
    setState(() => _isAuthenticatingBiometric = true);
    try {
      final isSupported = await _biometricService.isDeviceSupported();
      if (!isSupported && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('BIOMETRIC HARDWARE SENSOR NOT DETECTED',
                style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w700)),
            backgroundColor: AppColors.surface,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final authenticated = await _biometricService.authenticate(
        reason: 'Authenticate with Fingerprint or Face ID to access PrivacyShield',
      );

      if (!authenticated || !mounted) return;

      final creds = await _biometricService.getSavedCredentials();
      if (!mounted) return;
      final auth = context.read<AuthProvider>();

      if (creds['email'] != null && creds['token'] != null) {
        // Authenticate using bound passkey credentials
        final success = await auth.login(creds['email']!, creds['token']!);
        if (success && mounted) {
          Navigator.pushReplacementNamed(context, '/home');
          return;
        }
      }

      // If credentials not yet bound, check if fields are populated
      if (_emailCtrl.text.isNotEmpty && _passwordCtrl.text.isNotEmpty) {
        await _login();
      } else {
        // Auto-fill demo credentials for instant hackathon walkthrough
        _emailCtrl.text = 'demo@privacyshield.io';
        _passwordCtrl.text = 'password123';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('BIOMETRIC ENCLAVE VERIFIED · READY TO SIGN IN',
                  style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w700)),
              backgroundColor: AppColors.surface,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isAuthenticatingBiometric = false);
      }
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border, width: 1.0),
                        ),
                        child: const Icon(Icons.shield_outlined, size: 28, color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'VAULT ACCESS',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 2.0),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Cryptographic privacy & footprint telemetry',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.spaceGrotesk(color: AppColors.textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 36),
                    if (auth.error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.red.withAlpha(120), width: 1.0),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.red, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(auth.error!, style: const TextStyle(color: AppColors.red, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'IDENTIFIER / EMAIL',
                        prefixIcon: Icon(Icons.alternate_email, color: AppColors.textMuted, size: 18),
                      ),
                      validator: (v) => v != null && v.contains('@') ? null : 'Enter a valid email',
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'PASSPHRASE',
                        prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textMuted, size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: AppColors.textMuted,
                            size: 18,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) => v != null && v.length >= 6 ? null : 'Min 6 characters',
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: auth.isLoading ? null : _login,
                      child: auth.isLoading
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background))
                          : const Text('AUTHENTICATE'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: (_isAuthenticatingBiometric || auth.isLoading) ? null : _handleBiometricAuth,
                      icon: _isAuthenticatingBiometric
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textPrimary))
                          : const Icon(Icons.fingerprint, color: AppColors.textPrimary, size: 18),
                      label: Text(_isAuthenticatingBiometric ? 'SCANNING ENCLAVE...' : 'BIOMETRIC PASSKEY'),
                    ),
                    const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text("Don't have an account? ", style: TextStyle(color: AppColors.textSecondary)),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacementNamed(context, '/register'),
                      child: const Text('Sign Up', style: TextStyle(color: AppColors.blue, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);
  }
}
