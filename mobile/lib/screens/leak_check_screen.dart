import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../config/theme.dart';

class LeakResult {
  final String hash;
  final int count;
  final int candidates;
  final String crackTime;

  const LeakResult({
    required this.hash,
    required this.count,
    required this.candidates,
    required this.crackTime,
  });
}

const _guessesPerSecond = 1e10;

String estimateCrackTime(String password) {
  var pool = 0;
  if (RegExp(r'[a-z]').hasMatch(password)) pool += 26;
  if (RegExp(r'[A-Z]').hasMatch(password)) pool += 26;
  if (RegExp(r'[0-9]').hasMatch(password)) pool += 10;
  if (RegExp(r'[^a-zA-Z0-9]').hasMatch(password)) pool += 33;
  final seconds = pow(pool.toDouble(), password.length) / 2 / _guessesPerSecond;

  const year = 60 * 60 * 24 * 365;
  if (!seconds.isFinite || seconds > year * 1e6) return 'millions of years';
  const units = [
    (year * 100, 'centuries'),
    (year, 'years'),
    (60 * 60 * 24, 'days'),
    (60 * 60, 'hours'),
    (60, 'minutes'),
    (1, 'seconds'),
  ];
  for (final (size, label) in units) {
    if (seconds >= size) {
      return '~${NumberFormat.decimalPattern().format((seconds / size).round())} $label';
    }
  }
  return 'instantly';
}

Future<LeakResult> checkPasswordLeak(String password) async {
  final hash = sha1.convert(utf8.encode(password)).toString().toUpperCase();
  final res = await http
      .get(Uri.parse('https://api.pwnedpasswords.com/range/${hash.substring(0, 5)}'))
      .timeout(const Duration(seconds: 10));
  if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');

  final lines = const LineSplitter().convert(res.body);
  final suffix = hash.substring(5);
  var count = 0;
  for (final line in lines) {
    final parts = line.split(':');
    if (parts.length == 2 && parts[0].toUpperCase() == suffix) {
      count = int.tryParse(parts[1].trim()) ?? 0;
      break;
    }
  }
  return LeakResult(
    hash: hash,
    count: count,
    candidates: lines.length,
    crackTime: estimateCrackTime(password),
  );
}

class LeakCheckScreen extends StatefulWidget {
  const LeakCheckScreen({super.key});

  @override
  State<LeakCheckScreen> createState() => _LeakCheckScreenState();
}

class _LeakCheckScreenState extends State<LeakCheckScreen> {
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;
  LeakResult? _result;

  Future<void> _check() async {
    final password = _controller.text;
    if (password.isEmpty || _loading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await checkPasswordLeak(password);
      if (mounted) setState(() => _result = result);
    } catch (_) {
      if (mounted) {
        setState(() => _error = "Couldn't reach the breach database. Check your connection and try again.");
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Password Leak Check')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Has your password already leaked?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Checked against 900M+ real breached passwords. No signup. Nothing stored.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _controller,
                obscureText: _obscure,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _check(),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Type any password',
                  prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textMuted),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: AppColors.textMuted),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
                onPressed: _controller.text.isEmpty || _loading ? null : _check,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Check leaks'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.red, fontSize: 13)),
              ],
              if (result != null) ...[
                const SizedBox(height: 32),
                result.count > 0
                    ? _FoundResult(key: ValueKey(result.hash), count: result.count)
                    : _CleanResult(crackTime: result.crackTime),
                const SizedBox(height: 24),
                _HashReveal(hash: result.hash, candidates: result.candidates),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FoundResult extends StatelessWidget {
  final int count;

  const _FoundResult({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    final label = count >= 100000
        ? 'EXTREMELY COMMON'
        : count >= 1000
            ? 'WIDELY LEAKED'
            : 'LEAKED';
    final format = NumberFormat.decimalPattern();
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.red, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 2)),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: count.toDouble()),
          duration: const Duration(milliseconds: 1400),
          curve: Curves.easeOutCubic,
          builder: (_, value, _) => FittedBox(
            child: Text(
              format.format(value.round()),
              style: const TextStyle(
                color: AppColors.red,
                fontSize: 52,
                fontWeight: FontWeight.bold,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'times this exact password appears in real data breaches.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17),
        ),
        const SizedBox(height: 12),
        const Text.rich(
          TextSpan(
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            children: [
              TextSpan(text: 'Attackers try leaked lists first, so any account using it can be taken over '),
              TextSpan(text: 'instantly', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w600)),
              TextSpan(text: '. If you reuse it, every one of those accounts falls together.'),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _CleanResult extends StatelessWidget {
  final String crackTime;

  const _CleanResult({required this.crackTime});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('NOT FOUND IN KNOWN BREACHES',
            style: TextStyle(color: AppColors.green, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 2)),
        const SizedBox(height: 8),
        const Text('0 leaks', style: TextStyle(color: AppColors.green, fontSize: 36, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            children: [
              const TextSpan(text: 'Rough brute-force estimate: '),
              TextSpan(
                  text: crackTime,
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
              const TextSpan(
                  text: " to crack at 10 billion guesses/sec. Not being leaked yet doesn't make it safe to reuse."),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _HashReveal extends StatelessWidget {
  final String hash;
  final int candidates;

  const _HashReveal({required this.hash, required this.candidates});

  @override
  Widget build(BuildContext context) {
    const mono = TextStyle(fontFamily: 'monospace', fontFamilyFallback: ['Menlo', 'Courier'], fontSize: 13);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SHA-1 of your password, computed on this device:',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 8),
          Text.rich(TextSpan(children: [
            TextSpan(
              text: hash.substring(0, 5),
              style: mono.copyWith(
                color: AppColors.blue,
                fontWeight: FontWeight.bold,
                backgroundColor: AppColors.blue.withAlpha(30),
              ),
            ),
            TextSpan(text: hash.substring(5), style: mono.copyWith(color: AppColors.borderHover)),
          ])),
          const SizedBox(height: 10),
          const Text.rich(TextSpan(
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            children: [
              TextSpan(text: 'Sent: ', style: TextStyle(color: AppColors.blue, fontWeight: FontWeight.w600)),
              TextSpan(text: 'only the first 5 characters'),
            ],
          )),
          const SizedBox(height: 4),
          Text.rich(TextSpan(
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            children: [
              const TextSpan(
                  text: 'Received: ', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w600)),
              TextSpan(text: '${NumberFormat.decimalPattern().format(candidates)} candidate hashes, matched locally'),
            ],
          )),
          const SizedBox(height: 8),
          const Text('Your password and its full hash never left this device (k-anonymity).',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}
