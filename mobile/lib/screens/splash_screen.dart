import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../services/auth_provider.dart';
import '../services/server_discovery.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    );
    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.6, curve: Curves.easeOut)),
    );
    _controller.forward();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final results = await Future.wait([
      ServerDiscovery.discover(),
      Future.delayed(const Duration(milliseconds: 2300)),
    ]);
    if (!mounted) return;
    if (results[0] == null) {
      Navigator.pushReplacementNamed(context, '/server');
      return;
    }
    final auth = context.read<AuthProvider>();
    final isAuth = await auth.checkAuth();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, isAuth ? '/home' : '/login');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const _boot = [
    'Locating your server',
    'Opening encrypted file',
    'Cross-checking breach records',
    'Mapping account network',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('CLASSIFIED · EYES ONLY', style: AppText.eyebrow(color: AppColors.red)),
                    const Spacer(),
                    Text('REF PS-${DateTime.now().year}', style: AppText.eyebrow()),
                  ],
                ),
                Container(height: 2, color: AppColors.ink, margin: const EdgeInsets.only(top: 8)),
                const Spacer(),
                Opacity(
                  opacity: _fadeIn.value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - _fadeIn.value)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(width: 22, height: 22, color: AppColors.red),
                        const SizedBox(height: 18),
                        Text('Privacy', style: AppText.serif(size: 72)),
                        Text('Shield', style: AppText.serif(size: 72, style: FontStyle.italic)),
                        const SizedBox(height: 10),
                        Text('Your digital exposure, on the record.', style: AppText.serif(size: 22, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                for (var i = 0; i < _boot.length; i++)
                  if (_controller.value > i / _boot.length)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '> ${_boot[i].toUpperCase()}${_controller.value > (i + 1) / _boot.length ? '  ·  OK' : '…'}',
                        style: AppText.mono(size: 12, color: _controller.value > (i + 1) / _boot.length ? AppColors.ink : AppColors.red),
                      ),
                    ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Opacity(
                    opacity: _controller.value > 0.55 ? 1 : 0,
                    child: const _SlamStamp(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SlamStamp extends StatelessWidget {
  const _SlamStamp();

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: -0.12,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(border: Border.all(color: AppColors.red, width: 3)),
      child: Text('CONFIDENTIAL', style: AppText.mono(size: 18, color: AppColors.red, weight: FontWeight.w700).copyWith(letterSpacing: 3)),
    ),
  );
}
