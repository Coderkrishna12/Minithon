import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../services/api_service.dart';

class BreachesScreen extends StatefulWidget {
  const BreachesScreen({super.key});

  @override
  State<BreachesScreen> createState() => _BreachesScreenState();
}

class _BreachesScreenState extends State<BreachesScreen> with SingleTickerProviderStateMixin {
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
        _predictions = (data['predictions'] as List?) ?? [];
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
          decoration: const BoxDecoration(
            color: AppColors.background,
            border: Border(bottom: BorderSide(color: AppColors.border, width: 1.0)),
          ),
          child: TabBar(
            controller: _tabCtrl,
            indicatorColor: AppColors.textPrimary,
            indicatorWeight: 1.5,
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textMuted,
            labelStyle: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
            unselectedLabelStyle: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 1.0),
            tabs: const [
              Tab(text: 'SCAN'),
              Tab(text: 'INCIDENTS'),
              Tab(text: 'PREDICTIONS'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [_buildScanTab(), _buildHistoryTab(), _buildPredictionsTab()],
          ),
        ),
      ],
    );
  }

  Widget _buildScanTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border, width: 1.0),
                ),
                child: const Icon(Icons.radar_outlined, size: 44, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 24),
              Text(
                'THREAT SURFACE AUDIT',
                style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1.5),
              ),
              const SizedBox(height: 8),
              Text(
                'Cross-reference vaulted credentials against global leak indexes and known threat databases',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: _scanning ? null : _scanAll,
                icon: _scanning
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background))
                    : const Icon(Icons.search, size: 18),
                label: Text(_scanning ? 'EXECUTING AUDIT...' : 'RUN GLOBAL SCAN'),
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
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${_scanResult!['accounts_scanned'] ?? 0} accounts scanned',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildHistoryTab() {
    if (_loadingHistory) {
      return const Center(child: CircularProgressIndicator(color: AppColors.textPrimary));
    }
    if (_history.isEmpty) {
      return Center(
        child: Text(
          'NO VERIFIED BREACHES DETECTED',
          style: GoogleFonts.spaceGrotesk(color: AppColors.textMuted, fontSize: 12, letterSpacing: 1.0),
        ),
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _history.length,
          itemBuilder: (_, i) {
            final b = _history[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border, width: 1.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.red.withAlpha(120), width: 1.0),
                        ),
                        child: const Icon(Icons.priority_high, color: AppColors.red, size: 12),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          (b['breach_name'] ?? 'Unknown Incident').toString().toUpperCase(),
                          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.5),
                        ),
                      ),
                      if (b['source'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.border, width: 1.0),
                          ),
                          child: Text(
                            b['source'].toString().toUpperCase(),
                            style: GoogleFonts.spaceGrotesk(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.titanium),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'PLATFORM: ${b['account_name'] ?? b['service_name'] ?? 'N/A'}',
                    style: GoogleFonts.spaceGrotesk(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  if (b['breach_date'] != null)
                    Text(
                      'LOGGED DATE: ${b['breach_date']}',
                      style: GoogleFonts.spaceGrotesk(color: AppColors.textMuted, fontSize: 11),
                    ),
                  if (b['data_exposed'] != null && (b['data_exposed'] as List).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: (b['data_exposed'] as List).map((d) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.border, width: 1.0),
                            ),
                            child: Text(
                              d.toString().toUpperCase(),
                              style: GoogleFonts.spaceGrotesk(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPredictionsTab() {
    if (_loadingPredictions) {
      return const Center(child: CircularProgressIndicator(color: AppColors.textPrimary));
    }
    if (_predictions.isEmpty) {
      return Center(
        child: Text(
          'NO ACTIVE PREDICTIVE THREATS',
          style: GoogleFonts.spaceGrotesk(color: AppColors.textMuted, fontSize: 12, letterSpacing: 1.0),
        ),
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _predictions.length,
          itemBuilder: (_, i) {
            final p = _predictions[i];
            final prob = ((p['probability'] ?? 0) * 100).toDouble();
            final color = prob >= 70 ? AppColors.red : prob >= 40 ? AppColors.orange : AppColors.green;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
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
                        (p['service_name'] ?? '').toString().toUpperCase(),
                        style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.5),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: color.withAlpha(120), width: 1.0),
                        ),
                        child: Text(
                          '${prob.toInt()}% PROBABILITY',
                          style: GoogleFonts.spaceGrotesk(color: color, fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: 0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: prob / 100,
                      backgroundColor: AppColors.surfaceLight,
                      valueColor: AlwaysStoppedAnimation(color),
                      minHeight: 4,
                    ),
                  ),
                  if (p['risk_factors'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'RISK FACTORS: ${(p['risk_factors'] as List).join(' // ').toUpperCase()}',
                      style: GoogleFonts.spaceGrotesk(color: AppColors.textMuted, fontSize: 10, letterSpacing: 0.5),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
