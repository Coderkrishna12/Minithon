import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/account.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../widgets/cyber.dart';
import '../widgets/dossier.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _dashboard;
  List<FixAction> _fixes = [];
  int _accountsWith2fa = 0;
  List<dynamic> _accounts = [];
  // The boot scan plays once per app session, the first time the overview loads.
  static bool _bootScanPlayed = false;
  bool _showBootScan = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.get('/dashboard/'),
        _api.getList('/dashboard/fixes'),
        _api.getList('/accounts/'),
      ]);
      setState(() {
        _dashboard = results[0] as Map<String, dynamic>;
        _fixes = (results[1] as List)
            .map((e) => FixAction.fromJson(e))
            .toList();
        _accounts = results[2] as List;
        if (!_bootScanPlayed && _accounts.isNotEmpty) {
          _bootScanPlayed = true;
          _showBootScan = true;
        }
        _accountsWith2fa = _accounts.where((account) => account['has_2fa'] == true).length;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _completeFix(int fixId) async {
    try {
      final completed = await _api.patch('/dashboard/fixes/$fixId/complete');
      await _loadData();
      if (mounted) {
        final receipt = completed['blockchain_tx_hash']?.toString();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(receipt == null
              ? 'Confirmation recorded in your local audit chain.'
              : 'Confirmation recorded · receipt ${receipt.substring(0, receipt.length > 12 ? 12 : receipt.length)}…'),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not record this fix: $e')));
    }
  }

  Future<void> _previewFix(FixAction fix) async {
    try {
      final preview = await _api.get('/dashboard/fixes/${fix.id}/preview');
      if (!mounted) return;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Review this fix'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${preview['account']}: ${fix.description}'),
            const SizedBox(height: 12),
            Text('Estimated privacy score: ${preview['before_score']} → ${preview['after_score']} (+${preview['score_improvement']})'),
            Text('Estimated time: ${preview['estimated_minutes']} minutes'),
            const SizedBox(height: 12),
            const Text('This does not change the service account. Make the change with the service first, then confirm it here.', style: TextStyle(fontSize: 12)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('I completed it')),
          ],
        ),
      );
      if (accepted == true) await _completeFix(fix.id);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not preview this fix: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.red));
    }

    final d = _dashboard;
    if (d == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const RubberStamp('File unavailable', delay: Duration.zero),
            const SizedBox(height: 20),
            const Text("Couldn't reach your PrivacyShield server.", style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      );
    }

    final user = context.watch<AuthProvider>().user;
    final score = ((d['privacy_score'] ?? 0) as num).round();
    final totalAccounts = (d['total_accounts'] ?? 0) as int;
    final totalBreaches = (d['total_breaches'] ?? d['breaches_found'] ?? 0) as int;
    final atRisk = (d['accounts_at_risk'] ?? 0) as int;
    final riskDistribution = d['risk_distribution'] as Map<String, dynamic>? ?? {};
    final spofs = (d['single_points_of_failure'] as List?) ?? [];
    final pendingFixes = _fixes.where((f) => f.status == 'pending').toList();
    final done = _fixes.where((f) => f.status == 'completed').length;
    final no2fa = totalAccounts - _accountsWith2fa;
    final verdict = score >= 80
        ? ('Secured', AppColors.green)
        : score >= 60
        ? ('Under watch', AppColors.ink)
        : score >= 40
        ? ('Exposed', AppColors.orange)
        : ('At risk', AppColors.red);

    final ticker = <String>[
      'Privacy score $score/100',
      '$totalBreaches breach${totalBreaches == 1 ? '' : 'es'} on record',
      '$no2fa account${no2fa == 1 ? '' : 's'} without 2FA',
      for (final s in spofs.take(2))
        '${s['service_name']} unlocks ${(s['risk_components']?['reachable_accounts'] ?? 0)} accounts',
      '${pendingFixes.length} fixes waiting',
      'Monitoring live',
    ];

    final accounts = _accounts.cast<Map<String, dynamic>>();
    if (_showBootScan) {
      return BootScan(accounts: accounts, onDone: () => setState(() => _showBootScan = false));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.red,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          TickerTape(items: ticker),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: ShieldStatus(accounts: totalAccounts),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Eyebrow('Subject file № PS-${(user?.id ?? 0).toString().padLeft(4, '0')}'),
                    const Spacer(),
                    Flexible(child: Eyebrow(DateFormat('dd MMM yyyy').format(DateTime.now()))),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  user?.fullName?.isNotEmpty == true ? '${user!.fullName},\non the record.' : 'Your exposure,\non the record.',
                  style: AppText.serif(size: 40),
                ),
                const SizedBox(height: 18),
                _scoreFile(score, verdict, totalAccounts),
                const SizedBox(height: 14),
                _exhibits(totalAccounts, atRisk, totalBreaches, no2fa),
                if (accounts.isNotEmpty) ...[
                  const CaseHeading(code: 'Section 01 · Live', title: 'Surveillance'),
                  ThreatRadar(accounts: accounts),
                  const SizedBox(height: 8),
                  LiveConsole(accounts: accounts),
                ],
                const CaseHeading(code: 'Section 02', title: 'Operations'),
                _operations(),
                const CaseHeading(code: 'Section 03', title: 'Risk profile'),
                _riskStrip(riskDistribution),
                if (spofs.isNotEmpty) ...[
                  const CaseHeading(code: 'Section 04', title: 'Keystone accounts'),
                  const Text(
                    'Lose one of these and the rest follow.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  ...spofs.map(_buildSpofCard),
                ],
                CaseHeading(
                  code: spofs.isEmpty ? 'Section 04' : 'Section 05',
                  title: 'Orders',
                  trailing: Eyebrow('$done done · ${pendingFixes.length} open'),
                ),
                if (pendingFixes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Align(alignment: Alignment.centerLeft, child: RubberStamp('All clear', color: AppColors.green)),
                  )
                else
                  ...pendingFixes.take(6).toList().asMap().entries.map((e) => _buildFixCard(e.value, e.key + 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreFile(int score, (String, Color) verdict, int accounts) {
    return FilePanel(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: ScanLine(
        child: Column(
          children: [
            Row(
              children: [
                const Eyebrow('Exhibit 01 · Score', color: AppColors.textSecondary),
                const Spacer(),
                Flexible(child: Eyebrow('$accounts assessed')),
              ],
            ),
            const SizedBox(height: 8),
            Stack(
              alignment: Alignment.center,
              children: [
                ScoreDial(score: score),
                Positioned(
                  right: 0,
                  bottom: 16,
                  child: RubberStamp(verdict.$1, color: verdict.$2, delay: const Duration(milliseconds: 1500)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _exhibits(int accounts, int atRisk, int breaches, int no2fa) {
    Widget cell(String code, String value, String label, Color color) => Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow(code),
            const SizedBox(height: 6),
            Redacted(
              delay: const Duration(milliseconds: 500),
              child: Text(value, style: AppText.serif(size: 40, color: color)),
            ),
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
          ],
        ),
      ),
    );
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              cell('Exhibit 02', '$accounts', 'accounts on file', AppColors.ink),
              const SizedBox(width: 8),
              cell('Exhibit 03', '$atRisk', 'at high risk', atRisk > 0 ? AppColors.red : AppColors.green),
            ],
          ),
        ),
        const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              cell('Exhibit 04', '$breaches', 'breaches found', breaches > 0 ? AppColors.red : AppColors.green),
              const SizedBox(width: 8),
              cell('Exhibit 05', '$no2fa', 'without 2FA', no2fa > 0 ? AppColors.orange : AppColors.green),
            ],
          ),
        ),
      ],
    );
  }

  Widget _operations() {
    const ops = [
      ('OP-01', 'Hack Me', 'Stage a break-in on your own accounts', Icons.bug_report_outlined, '/hack-me'),
      ('OP-02', 'Exposure scan', 'What a hacker already knows about any email', Icons.radar, '/exposure'),
      ('OP-03', 'Family Shield', 'Watch over the people you love', Icons.shield_outlined, '/family'),
      ('OP-04', 'Dark web sweep', 'Find where your data is traded', Icons.travel_explore, '/darkweb'),
      ('OP-05', 'Leak check', 'Test a password against known leaks', Icons.password, '/leak-check'),
      ('OP-06', 'QR inspection', 'Scan a code before you trust it', Icons.qr_code_scanner, '/qr-scanner'),
      ('OP-07', 'AI insights', 'Ask what to fix first', Icons.auto_awesome_outlined, '/ai-insights'),
    ];
    return Column(
      children: [
        // The flagship operation gets the full width, in ink.
        _opTile(ops.first, featured: true),
        const SizedBox(height: 8),
        for (var i = 1; i < ops.length; i += 2) ...[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _opTile(ops[i])),
                const SizedBox(width: 8),
                Expanded(child: i + 1 < ops.length ? _opTile(ops[i + 1]) : const SizedBox()),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _opTile((String, String, String, IconData, String) op, {bool featured = false}) {
    final (code, title, line, icon, route) = op;
    final fg = featured ? AppColors.background : AppColors.textPrimary;
    return Material(
      color: featured ? AppColors.ink : AppColors.surface,
      shape: const RoundedRectangleBorder(side: BorderSide(color: AppColors.ink, width: 1.2)),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, route),
        child: Padding(
          padding: EdgeInsets.all(featured ? 18 : 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(code, color: featured ? AppColors.red : AppColors.textMuted),
                    const SizedBox(height: 6),
                    Text(title, style: AppText.serif(size: featured ? 30 : 22, color: fg)),
                    const SizedBox(height: 4),
                    Text(
                      line,
                      style: TextStyle(color: featured ? AppColors.paperDark : AppColors.textSecondary, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Icon(icon, color: featured ? AppColors.red : AppColors.ink, size: featured ? 34 : 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _riskStrip(Map<String, dynamic> dist) {
    const levels = [
      ('critical', 'Critical', AppColors.red),
      ('high', 'High', AppColors.orange),
      ('medium', 'Medium', AppColors.textSecondary),
      ('low', 'Low', AppColors.green),
    ];
    final total = levels.fold<int>(0, (sum, l) => sum + ((dist[l.$1] ?? 0) as int));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // One printed bar: each account is a stripe, coloured by its risk.
        SizedBox(
          height: 44,
          child: total == 0
              ? Container(color: AppColors.paperDark)
              : Row(
                  children: [
                    for (final (key, _, color) in levels)
                      for (var i = 0; i < ((dist[key] ?? 0) as int); i++)
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            color: color,
                          ),
                        ),
                  ],
                ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final (key, label, color) in levels)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${dist[key] ?? 0}', style: AppText.serif(size: 26, color: color)),
                    Eyebrow(label),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSpofCard(dynamic spof) {
    final name = spof['service_name'] ?? 'Unknown';
    final reach = spof['risk_components']?['reachable_accounts'] ?? 0;
    final protected = spof['has_2fa'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          left: const BorderSide(color: AppColors.red, width: 4),
          top: const BorderSide(color: AppColors.border),
          right: const BorderSide(color: AppColors.border),
          bottom: const BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppText.serif(size: 24)),
                Text(
                  'Unlocks $reach other account${reach == 1 ? '' : 's'}${protected ? ' · 2FA on' : ' · no 2FA'}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                ),
              ],
            ),
          ),
          RubberStamp('Keystone', fontSize: 12, delay: const Duration(milliseconds: 200), color: protected ? AppColors.orange : AppColors.red),
        ],
      ),
    );
  }

  Widget _buildFixCard(FixAction fix, int number) {
    return InkWell(
      onTap: () => _previewFix(fix),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 34,
              child: Text(number.toString().padLeft(2, '0'), style: AppText.mono(size: 13, color: AppColors.red, weight: FontWeight.w700)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fix.description, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 3),
                  Eyebrow('Raises score by ${fix.riskReduction.toStringAsFixed(0)} pts · tap to review', color: AppColors.green),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward, size: 18, color: AppColors.ink),
          ],
        ),
      ),
    );
  }
}
