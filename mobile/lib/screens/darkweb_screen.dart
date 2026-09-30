import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/api_service.dart';

class DarkWebScreen extends StatefulWidget {
  const DarkWebScreen({super.key});

  @override
  State<DarkWebScreen> createState() => _DarkWebScreenState();
}

class _DarkWebScreenState extends State<DarkWebScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  List<dynamic> _alerts = [];
  bool _loading = true;
  bool _scanning = false;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _loadAlerts();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAlerts() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getList('/darkweb/alerts');
      setState(() {
        _alerts = data;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    _pulseCtrl.repeat();
    try {
      await _api.post('/darkweb/scan');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dark web scan complete')),
        );
      }
      _loadAlerts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e')),
        );
      }
    }
    _pulseCtrl.stop();
    _pulseCtrl.reset();
    setState(() => _scanning = false);
  }

  Future<void> _resolveAlert(int alertId) async {
    try {
      await _api.patch('/darkweb/alerts/$alertId/resolve');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alert resolved')),
        );
      }
      _loadAlerts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resolve: $e')),
        );
      }
    }
  }

  Color _severityColor(String? severity) {
    switch (severity) {
      case 'critical':
        return AppColors.red;
      case 'warning':
        return AppColors.orange;
      default:
        return AppColors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dark Web Monitor')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.blue))
          : RefreshIndicator(
              onRefresh: _loadAlerts,
              color: AppColors.blue,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildScanButton(),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Icon(Icons.warning_amber, color: AppColors.orange, size: 20),
                      const SizedBox(width: 8),
                      const Text('Alerts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.red.withAlpha(30),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_alerts.length}',
                          style: const TextStyle(color: AppColors.red, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_alerts.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.check_circle, color: AppColors.green, size: 48),
                          SizedBox(height: 12),
                          Text('No alerts found', style: TextStyle(color: AppColors.textSecondary)),
                          SizedBox(height: 4),
                          Text(
                            'Your data was not found on the dark web',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._alerts.map((alert) => _buildAlertCard(alert)),
                ],
              ),
            ),
    );
  }

  Widget _buildScanButton() {
    return Center(
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, child) {
              final scale = _scanning ? 1.0 + (_pulseCtrl.value * 0.15) : 1.0;
              final opacity = _scanning ? 0.3 + (_pulseCtrl.value * 0.3) : 0.3;
              return Stack(
                alignment: Alignment.center,
                children: [
                  if (_scanning)
                    Container(
                      width: 120 * scale,
                      height: 120 * scale,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.red.withAlpha((opacity * 255).toInt()),
                      ),
                    ),
                  GestureDetector(
                    onTap: _scanning ? null : _scan,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.red.withAlpha(30),
                        border: Border.all(color: AppColors.red, width: 2),
                      ),
                      child: _scanning
                          ? const Center(
                              child: CircularProgressIndicator(color: AppColors.red, strokeWidth: 3),
                            )
                          : const Icon(Icons.radar, size: 40, color: AppColors.red),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            _scanning ? 'Scanning dark web...' : 'Tap to scan',
            style: TextStyle(
              color: _scanning ? AppColors.red : AppColors.textSecondary,
              fontWeight: _scanning ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(dynamic alert) {
    final severity = alert['severity'] as String? ?? 'warning';
    final color = _severityColor(severity);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.dark_mode, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert['source'] ?? 'Unknown Source',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      severity.toUpperCase(),
                      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (alert['data_found'] != null) ...[
            const SizedBox(height: 10),
            const Text('Data Found:', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              alert['data_found'].toString(),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _resolveAlert(alert['id']),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Resolve'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.green,
                side: const BorderSide(color: AppColors.green),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
