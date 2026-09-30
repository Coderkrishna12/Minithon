import 'package:flutter/material.dart';
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
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
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
          ),
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
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildRiskDistribution(Map<String, dynamic> dist) {
    final levels = ['critical', 'high', 'medium', 'low'];
    final colors = [AppColors.red, AppColors.orange, AppColors.blue, AppColors.green];
    final total = levels.fold<int>(0, (sum, l) => sum + ((dist[l] ?? 0) as int));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Risk Distribution', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
                        levels[i][0].toUpperCase() + levels[i].substring(1),
                        style: TextStyle(color: colors[i], fontWeight: FontWeight.w500, fontSize: 13),
                      ),
                      Text('$count', style: TextStyle(color: colors[i], fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: AppColors.surfaceLight,
                      valueColor: AlwaysStoppedAnimation(colors[i]),
                      minHeight: 6,
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.red.withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning, color: AppColors.red, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  'Could cascade to $impact accounts',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.red.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$impact', style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.bold, fontSize: 12)),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fix.description, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  'Risk reduction: -${fix.riskReduction.toStringAsFixed(0)} pts',
                  style: const TextStyle(color: AppColors.green, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check_circle_outline, color: AppColors.green),
            onPressed: () => _completeFix(fix.id),
          ),
        ],
      ),
    );
  }
}
