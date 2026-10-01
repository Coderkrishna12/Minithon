import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/api_service.dart';

class BreachesScreen extends StatefulWidget {
  const BreachesScreen({super.key});

  @override
  State<BreachesScreen> createState() => _BreachesScreenState();
}

class _BreachesScreenState extends State<BreachesScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tabCtrl;
  List<dynamic> _history = [];
  List<dynamic> _predictions = [];
  bool _scanning = false;
  bool _loadingHistory = true;
  bool _loadingPredictions = true;
  Map<String, dynamic>? _scanResult;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadHistory();
    _loadPredictions();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final data = await _api.getList('/breaches/history');
      setState(() {
        _history = data;
        _loadingHistory = false;
      });
    } catch (_) {
      setState(() => _loadingHistory = false);
    }
  }

  Future<void> _loadPredictions() async {
    try {
      final data = await _api.get('/ai/breach-predictions');
      setState(() {
        _predictions =
            (data['data'] as List?) ?? (data['predictions'] as List?) ?? [];
        _loadingPredictions = false;
      });
    } catch (_) {
      setState(() => _loadingPredictions = false);
    }
  }

  Future<void> _scanAll() async {
    setState(() => _scanning = true);
    try {
      final data = await _api.post('/breaches/scan-all');
      setState(() {
        _scanResult = data;
        _scanning = false;
      });
      _loadHistory();
    } catch (_) {
      setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AppColors.surface,
          child: TabBar(
            controller: _tabCtrl,
            indicatorColor: AppColors.blue,
            labelColor: AppColors.blue,
            unselectedLabelColor: AppColors.textMuted,
            tabs: const [
              Tab(text: 'Scan Now'),
              Tab(text: 'History'),
              Tab(text: 'Predictions'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildScanTab(),
              _buildHistoryTab(),
              _buildPredictionsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScanTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.red.withAlpha(30),
              ),
              child: const Icon(Icons.radar, size: 64, color: AppColors.red),
            ),
            const SizedBox(height: 24),
            const Text(
              'Breach Scanner',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Scan all your accounts against known data breaches',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _scanning ? null : _scanAll,
              icon: _scanning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.search),
              label: Text(_scanning ? 'Scanning...' : 'Scan All Accounts'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
            if (_scanResult != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Text(
                      'Found ${_scanResult!['total_breaches_found'] ?? 0} breaches',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_scanResult!['total_accounts_scanned'] ?? _scanResult!['accounts_scanned'] ?? 0} accounts scanned',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    if ((_scanResult!['unlisted_exposures'] as List?)
                            ?.isNotEmpty ==
                        true) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${(_scanResult!['unlisted_exposures'] as List).length} exposure(s) found for an email outside your account list.',
                        style: const TextStyle(
                          color: AppColors.orange,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if ((_scanResult!['errors'] as List?)?.isNotEmpty ==
                        true) ...[
                      const SizedBox(height: 8),
                      Text(
                        (_scanResult!['errors'] as List).join('\n'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.orange,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_loadingHistory) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.blue),
      );
    }
    if (_history.isEmpty) {
      return const Center(
        child: Text(
          'No breaches found',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      itemBuilder: (_, i) {
        final b = _history[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.warning_amber,
                    color: AppColors.red,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      b['breach_name'] ?? 'Unknown Breach',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Service: ${b['account_name'] ?? b['service_name'] ?? 'N/A'}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              if (b['breach_date'] != null)
                Text(
                  'Date: ${b['breach_date']}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              if (b['data_exposed'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: (b['data_exposed'] as List).map((d) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.red.withAlpha(30),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          d.toString(),
                          style: const TextStyle(
                            color: AppColors.red,
                            fontSize: 11,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPredictionsTab() {
    if (_loadingPredictions) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.blue),
      );
    }
    if (_predictions.isEmpty) {
      return const Center(
        child: Text(
          'No predictions available',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _predictions.length,
      itemBuilder: (_, i) {
        final p = _predictions[i];
        final prob =
            ((p['probability_6_months'] as num?) ??
                    ((p['probability'] as num? ?? 0) * 100))
                .toDouble();
        final color = prob >= 70
            ? AppColors.red
            : prob >= 40
            ? AppColors.orange
            : AppColors.green;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      p['service'] ?? p['service_name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${prob.toInt()}%',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: prob / 100,
                  backgroundColor: AppColors.surfaceLight,
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 6,
                ),
              ),
              if (p['factors'] is Map) ...[
                const SizedBox(height: 8),
                Text(
                  'Risk level: ${p['risk_level'] ?? 'unknown'} · ${p['recommendation'] ?? ''}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
