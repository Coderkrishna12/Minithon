import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../widgets/score_ring.dart';
import '../widgets/stat_card.dart';
import '../models/account.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _dashboard;
  List<FixAction> _fixes = [];
  bool _loading = true;
  bool _isSimulatingCascade = false;
  int _cascadeStep = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _triggerCascadeSimulation() {
    setState(() {
      _isSimulatingCascade = true;
      _cascadeStep = 1;
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _cascadeStep = 2);
    });
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _cascadeStep = 3);
    });
    Future.delayed(const Duration(milliseconds: 2100), () {
      if (mounted) setState(() => _cascadeStep = 4);
    });
  }

  void _resetCascadeSimulation() {
    setState(() {
      _isSimulatingCascade = false;
      _cascadeStep = 0;
    });
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.get('/dashboard/'),
        _api.getList('/dashboard/fixes'),
      ]);
      setState(() {
        _dashboard = results[0] as Map<String, dynamic>;
        _fixes = (results[1] as List).map((e) => FixAction.fromJson(e)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _completeFix(int fixId) async {
    try {
      await _api.patch('/dashboard/fixes/$fixId/complete');
      _loadData();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.blue));
    }

    final d = _dashboard;
    if (d == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text('Could not load dashboard', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      );
    }

    final score = (d['privacy_score'] ?? 0).toDouble();
    final totalAccounts = d['total_accounts'] ?? 0;
    final accountsAt2fa = d['accounts_with_2fa'] ?? 0;
    final totalBreaches = d['total_breaches'] ?? 0;
    final riskDistribution = d['risk_distribution'] as Map<String, dynamic>? ?? {};
    final spofs = (d['single_points_of_failure'] as List?) ?? [];
    final pendingFixes = _fixes.where((f) => f.status == 'pending').toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.blue,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(child: ScoreRing(score: score, size: 180, strokeWidth: 14)),
          const SizedBox(height: 8),
          const Center(
            child: Text('Privacy Score', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final isVeryNarrow = constraints.maxWidth < 280;
              final crossAxisCount = constraints.maxWidth > 700 ? 4 : (isVeryNarrow ? 1 : 2);
              final aspectRatio = isVeryNarrow
                  ? 2.2
                  : (constraints.maxWidth > 700 ? 1.4 : (constraints.maxWidth < 360 ? 1.05 : 1.3));
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: aspectRatio,
                children: [
                  StatCard(label: 'Accounts', value: '$totalAccounts', icon: Icons.apps, color: AppColors.blue),
                  StatCard(label: '2FA Enabled', value: '$accountsAt2fa', icon: Icons.verified_user, color: AppColors.green),
                  StatCard(label: 'Breaches', value: '$totalBreaches', icon: Icons.warning_amber, color: AppColors.red),
                  StatCard(
                    label: 'Fixes Pending',
                    value: '${pendingFixes.length}',
                    icon: Icons.build,
                    color: AppColors.orange,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          _buildAndroidSecurityCard(),
          const SizedBox(height: 20),
          _buildBlastRadiusSimulator(),
          const SizedBox(height: 24),
          _buildRiskDistribution(riskDistribution),
          const SizedBox(height: 24),
          if (spofs.isNotEmpty) ...[
            _buildSectionTitle('Single Points of Failure', Icons.error, AppColors.red),
            const SizedBox(height: 8),
            ...spofs.map((s) => _buildSpofCard(s)),
            const SizedBox(height: 24),
          ],
          if (pendingFixes.isNotEmpty) ...[
            _buildSectionTitle('Fix Checklist', Icons.checklist, AppColors.green),
            const SizedBox(height: 8),
            ...pendingFixes.take(5).map((f) => _buildFixCard(f)),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: AppColors.titanium, size: 16),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: GoogleFonts.spaceGrotesk(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildRiskDistribution(Map<String, dynamic> dist) {
    final levels = ['critical', 'high', 'medium', 'low'];
    final colors = [AppColors.red, AppColors.orange, AppColors.titanium, AppColors.green];
    final total = levels.fold<int>(0, (sum, l) => sum + ((dist[l] ?? 0) as int));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'EXPOSURE SPREAD',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                '$total AUDITED',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(levels.length, (i) {
            final count = (dist[levels[i]] ?? 0) as int;
            final pct = total > 0 ? count / total : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        levels[i].toUpperCase(),
                        style: GoogleFonts.spaceGrotesk(
                          color: colors[i],
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        '$count',
                        style: GoogleFonts.spaceGrotesk(
                          color: colors[i],
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: AppColors.surfaceLight,
                      valueColor: AlwaysStoppedAnimation(colors[i]),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSpofCard(dynamic spof) {
    final name = spof['service_name'] ?? 'Unknown';
    final impact = spof['cascading_impact'] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 1.0),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.red.withAlpha(100), width: 1.0),
            ),
            child: const Icon(Icons.priority_high, color: AppColors.red, size: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 14)),
                Text(
                  'Cascades to $impact linked nodes',
                  style: GoogleFonts.spaceGrotesk(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.border, width: 1.0),
            ),
            child: Text(
              'IMPACT: $impact',
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.red,
                fontWeight: FontWeight.w700,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFixCard(FixAction fix) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 1.0),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fix.description, style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  'REDUCTION: -${fix.riskReduction.toStringAsFixed(0)} PTS',
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
            ),
            onPressed: () => _completeFix(fix.id),
            child: const Text('RESOLVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildAndroidSecurityCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border, width: 1.0),
                    ),
                    child: const Icon(Icons.shield_outlined, size: 16, color: AppColors.titanium),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'ANDROID ENDPOINT SENTRY',
                    style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: AppColors.textPrimary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'ENCLAVE ACTIVE',
                  style: GoogleFonts.spaceGrotesk(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.green),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Audits Android Accessibility trojans, tapjacking overlays, background surveillance, and arms motion pickpocket sentry.',
            style: GoogleFonts.spaceGrotesk(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/android-security'),
                  icon: const Icon(Icons.security, size: 14, color: AppColors.textPrimary),
                  label: const Text('OPEN ENDPOINT GUARD'),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/ar-scanner'),
                child: const Text('RF AIRSPACE'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBlastRadiusSimulator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _isSimulatingCascade ? AppColors.red.withValues(alpha: 0.4) : AppColors.border, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border, width: 1.0),
                    ),
                    child: Icon(Icons.bubble_chart_outlined, size: 16, color: _isSimulatingCascade ? AppColors.red : AppColors.titanium),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'ATTACK CASCADE & BLAST RADIUS',
                    style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: AppColors.textPrimary),
                  ),
                ],
              ),
              if (_isSimulatingCascade)
                Text(
                  'STEP $_cascadeStep / 4',
                  style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.red),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Simulate domino compromise across linked accounts when a primary credential leaks without 2FA.',
            style: GoogleFonts.spaceGrotesk(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
          ),
          const SizedBox(height: 14),
          if (_isSimulatingCascade) ...[
            _buildCascadeStepTile(1, 'ROOT INGESTION', 'Primary Google ID credentials matched in external dump', _cascadeStep >= 1),
            _buildCascadeStepTile(2, 'CREDENTIAL SPRAY', 'Automated stuffing against GitHub, AWS & Spotify nodes', _cascadeStep >= 2),
            _buildCascadeStepTile(3, 'PIVOT & HIJACK', 'Password recovery links intercepted via unsecured email', _cascadeStep >= 3),
            _buildCascadeStepTile(4, 'BLAST RADIUS: 78%', 'Critical financial & developer accounts breached', _cascadeStep >= 4, isCritical: true),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _triggerCascadeSimulation,
                  icon: Icon(_isSimulatingCascade ? Icons.replay : Icons.play_arrow, size: 16),
                  label: Text(_isSimulatingCascade ? 'RE-RUN ATTACK CASCADE' : 'SIMULATE THREAT CASCADE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSimulatingCascade ? AppColors.surfaceLight : AppColors.textPrimary,
                    foregroundColor: _isSimulatingCascade ? AppColors.textPrimary : AppColors.background,
                  ),
                ),
              ),
              if (_isSimulatingCascade) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _resetCascadeSimulation,
                  child: const Text('RESET'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCascadeStepTile(int step, String title, String desc, bool isActive, {bool isCritical = false}) {
    final color = isCritical ? AppColors.red : (isActive ? AppColors.amber : AppColors.textMuted);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isActive ? color.withValues(alpha: 0.08) : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isActive ? color.withValues(alpha: 0.4) : AppColors.border, width: 1.0),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? color : AppColors.surface,
            ),
            child: Text(
              '$step',
              style: TextStyle(
                color: isActive ? AppColors.background : AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w800, color: isActive ? color : AppColors.textMuted)),
                const SizedBox(height: 2),
                Text(desc, style: GoogleFonts.spaceGrotesk(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
