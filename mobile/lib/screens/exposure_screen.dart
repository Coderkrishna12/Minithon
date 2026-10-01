import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../widgets/dossier.dart';

/// "What a hacker already knows about you": a live exposure file for any email address.
class ExposureScreen extends StatefulWidget {
  const ExposureScreen({super.key});

  @override
  State<ExposureScreen> createState() => _ExposureScreenState();
}

const _bucketIcon = {
  'passwords': Icons.key,
  'financial': Icons.credit_card,
  'identity': Icons.badge_outlined,
  'location': Icons.location_on_outlined,
  'contact': Icons.phone_iphone,
  'social': Icons.alternate_email,
  'private': Icons.visibility_off_outlined,
};

const _scanSteps = [
  'Querying breach intelligence',
  'Cross-referencing the Have I Been Pwned catalogue',
  'Checking paste dumps',
  'Classifying leaked data',
  'Building attack profile',
];

class _ExposureScreenState extends State<ExposureScreen> {
  final _api = ApiService();
  final _emailCtrl = TextEditingController();
  bool _consent = false;
  bool _scanning = false;
  int _step = 0;
  Timer? _stepTimer;
  Map<String, dynamic>? _result;
  String? _error;
  bool _showAllBreaches = false;

  @override
  void dispose() {
    _stepTimer?.cancel();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final email = _emailCtrl.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Enter an email address.');
      return;
    }
    if (!_consent) {
      setState(() => _error = 'Tick the box to confirm you may look this address up.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _scanning = true;
      _error = null;
      _result = null;
      _step = 0;
      _showAllBreaches = false;
    });
    _stepTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (mounted && _step < _scanSteps.length - 1) setState(() => _step++);
    });
    try {
      final res = await _api.post('/exposure/scan', body: {'email': email, 'consent': true});
      // Let the scan sequence finish so the reveal lands after it.
      while (_step < _scanSteps.length - 1 && mounted) {
        await Future.delayed(const Duration(milliseconds: 150));
      }
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() => _result = res);
    } catch (e) {
      setState(() => _error = e is ApiException ? e.message : e.toString());
    } finally {
      _stepTimer?.cancel();
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _wipe() {
    setState(() {
      _result = null;
      _emailCtrl.clear();
      _consent = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wiped. Nothing about that address was ever saved.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exposure scan'),
        actions: [
          if (_result != null) IconButton(tooltip: 'Wipe', onPressed: _wipe, icon: const Icon(Icons.delete_sweep_outlined)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          if (_result == null) ...[
            const Eyebrow('Open-source intelligence', color: AppColors.red),
            const SizedBox(height: 4),
            Text('What does a hacker already know about you?', style: AppText.serif(size: 34)),
            const SizedBox(height: 8),
            const Text(
              'Type any email address. In a few seconds you will see every public breach it appears in, what leaked, '
              'and what an attacker can do with it. Nothing is saved.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              enabled: !_scanning,
              style: AppText.mono(size: 15),
              decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.alternate_email)),
              onSubmitted: (_) => _scan(),
            ),
            CheckboxListTile(
              value: _consent,
              onChanged: _scanning ? null : (v) => setState(() => _consent = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.ink,
              title: const Text('This is my address, or its owner said I can check it.', style: TextStyle(fontSize: 13.5)),
            ),
            ElevatedButton.icon(
              onPressed: _scanning ? null : _scan,
              icon: const Icon(Icons.radar),
              label: Text(_scanning ? 'Scanning…' : 'Run exposure scan'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.red)),
            ],
            if (_scanning) ...[const SizedBox(height: 20), _scanConsole()],
          ] else
            ..._report(_result!),
        ],
      ),
    );
  }

  Widget _scanConsole() => Container(
    color: AppColors.ink,
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i <= _step; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '> ${_scanSteps[i]}${i < _step ? '  ·  OK' : '…'}',
              style: AppText.mono(size: 11.5, color: i < _step ? const Color(0xFF8BC79B) : const Color(0xFFE5583F)),
            ),
          ),
        const SizedBox(height: 6),
        const LinearProgressIndicator(color: Color(0xFFE5583F), backgroundColor: Colors.white12, minHeight: 2),
      ],
    ),
  );

  List<Widget> _report(Map<String, dynamic> r) {
    final s = r['summary'] as Map<String, dynamic>;
    final breaches = (r['breaches'] as List).cast<Map<String, dynamic>>();
    final exposed = (r['exposed'] as List).cast<Map<String, dynamic>>();
    final attacks = (r['attacks'] as List).cast<Map<String, dynamic>>();
    final clear = r['level'] == 'clear';
    final fmt = NumberFormat.compact();
    final shown = _showAllBreaches ? breaches : breaches.take(12).toList();

    return [
      // The cover of the file.
      Container(
        color: AppColors.ink,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SUBJECT', style: AppText.mono(size: 10.5, color: const Color(0xFF8E897E)).copyWith(letterSpacing: 1.5)),
            const SizedBox(height: 2),
            Text(r['email'], style: AppText.mono(size: 15, color: AppColors.background, weight: FontWeight.w700)),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: RubberStamp(
                clear ? 'No known exposure' : 'Exposed in ${s['breaches']} breach${s['breaches'] == 1 ? '' : 'es'}',
                color: clear ? const Color(0xFF8BC79B) : const Color(0xFFE5583F),
                fontSize: 17,
                delay: const Duration(milliseconds: 200),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _coverStat(s['first_year'] == null ? '-' : '${s['years_exposed']}y', s['first_year'] == null ? 'exposed' : 'since ${s['first_year']}'),
                _coverStat('${s['password_breaches']}', 'password leaks'),
                _coverStat('${s['data_types']}', 'data types'),
                _coverStat('${s['pastes']}', 'paste dumps'),
              ],
            ),
          ],
        ),
      ),
      if (clear) ...[
        const SizedBox(height: 16),
        const Text(
          'This address is not in any public breach we know of. That is rare: keep it that way with a unique password and 2FA.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ] else ...[
        const CaseHeading(code: 'Section A', title: 'What a hacker already has'),
        for (final e in exposed) _exposedRow(e),
        const CaseHeading(code: 'Section B', title: 'What they can do with it'),
        for (var i = 0; i < attacks.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 34,
                  child: Text((i + 1).toString().padLeft(2, '0'), style: AppText.mono(size: 13, color: AppColors.red, weight: FontWeight.w700)),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(attacks[i]['title'], style: AppText.serif(size: 22)),
                      Text(attacks[i]['detail'], style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (r['worst'] != null) ...[
          const CaseHeading(code: 'Section C', title: 'The worst one'),
          _breachCard(r['worst'], highlight: true, fmt: fmt),
        ],
        CaseHeading(code: 'Section D', title: 'Every breach', trailing: Eyebrow('${breaches.length} on record')),
        for (final b in shown) _breachCard(b, fmt: fmt),
        if (breaches.length > shown.length)
          TextButton(
            onPressed: () => setState(() => _showAllBreaches = true),
            child: Text('Show all ${breaches.length}'),
          ),
      ],
      const SizedBox(height: 20),
      FilePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('Privacy', color: AppColors.green),
            const SizedBox(height: 4),
            Text(
              'Nothing about this address was saved. Sources: ${r['source'] == 'hibp' ? 'Have I Been Pwned' : 'XposedOrNot'} '
              'and the Have I Been Pwned breach catalogue. Checked ${r['checked_at'].toString().replaceAll('T', ' ').replaceAll('Z', ' UTC')}.',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(onPressed: _wipe, icon: const Icon(Icons.delete_sweep_outlined), label: const Text('Wipe')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/hack-me'),
                    icon: const Icon(Icons.bug_report_outlined),
                    label: const Text('Hack Me'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  Widget _coverStat(String value, String label) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppText.serif(size: 30, color: AppColors.background)),
        Text(label.toUpperCase(), style: AppText.mono(size: 9, color: const Color(0xFF8E897E))),
      ],
    ),
  );

  Widget _exposedRow(Map<String, dynamic> e) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          color: e['key'] == 'passwords' || e['key'] == 'financial' ? AppColors.red : AppColors.ink,
          child: Icon(_bucketIcon[e['key']] ?? Icons.help_outline, color: AppColors.background, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(e['label'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const Spacer(),
                  Eyebrow('in ${e['breaches']} breach${e['breaches'] == 1 ? '' : 'es'}'),
                ],
              ),
              const SizedBox(height: 4),
              Redacted(
                delay: const Duration(milliseconds: 400),
                child: Text(
                  (e['types'] as List).take(6).join(' · '),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _breachCard(Map<String, dynamic> b, {bool highlight = false, required NumberFormat fmt}) {
    final buckets = (b['buckets'] as List).cast<String>();
    final pw = buckets.contains('passwords');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight ? AppColors.ink : AppColors.surface,
        border: Border(
          left: BorderSide(color: pw ? AppColors.red : AppColors.border, width: pw ? 4 : 1),
          top: const BorderSide(color: AppColors.border),
          right: const BorderSide(color: AppColors.border),
          bottom: const BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  b['name'] ?? 'Unknown breach',
                  style: AppText.serif(size: highlight ? 26 : 21, color: highlight ? AppColors.background : AppColors.textPrimary),
                ),
              ),
              Text(
                b['year']?.toString() ?? '',
                style: AppText.mono(size: 13, color: highlight ? AppColors.background : AppColors.textSecondary, weight: FontWeight.w700),
              ),
            ],
          ),
          if (b['records'] != null)
            Text(
              '${fmt.format(b['records'])} accounts leaked${b['domain'] != null && b['domain'] != '' ? ' · ${b['domain']}' : ''}',
              style: AppText.mono(size: 10.5, color: highlight ? const Color(0xFF8E897E) : AppColors.textMuted),
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final d in (b['data'] as List).take(highlight ? 12 : 6))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: (d as String).toLowerCase().contains('password') ? AppColors.red : (highlight ? Colors.white30 : AppColors.border)),
                  ),
                  child: Text(
                    d,
                    style: TextStyle(
                      fontSize: 11,
                      color: d.toLowerCase().contains('password')
                          ? AppColors.red
                          : (highlight ? AppColors.paperDark : AppColors.textSecondary),
                    ),
                  ),
                ),
            ],
          ),
          if (highlight && b['description'] != null) ...[
            const SizedBox(height: 8),
            Text(b['description'], style: const TextStyle(color: AppColors.paperDark, fontSize: 12.5, height: 1.35)),
          ],
        ],
      ),
    );
  }
}
