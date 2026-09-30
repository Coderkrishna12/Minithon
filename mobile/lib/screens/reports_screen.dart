import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';
import '../services/api_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _summary;
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() => _loading = true);
    try {
      final data = await _api.get('/reports/summary');
      setState(() {
        _summary = data;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _exportReport() async {
    setState(() => _exporting = true);
    try {
      final data = await _api.get('/reports/export');
      final reportText = data['report'] ?? data.toString();
      await Clipboard.setData(ClipboardData(text: reportText.toString()));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report copied to clipboard')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
    setState(() => _exporting = false);
  }

  Color _gradeColor(String grade) {
    switch (grade.toUpperCase()) {
      case 'A':
      case 'A+':
        return AppColors.green;
      case 'B':
      case 'B+':
        return AppColors.blue;
      case 'C':
      case 'C+':
        return AppColors.orange;
      default:
        return AppColors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              if (_summary != null) {
                final messenger = ScaffoldMessenger.of(context);
                await Clipboard.setData(ClipboardData(
                  text: 'Privacy Score: ${_summary!['score'] ?? 'N/A'} | Grade: ${_summary!['grade'] ?? 'N/A'}',
                ));
                if (mounted) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Report copied to clipboard')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.blue))
          : _summary == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off, size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      const Text('Could not load report', style: TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadSummary, child: const Text('Retry')),
                    ],
                  ),
                )
              : _buildReport(),
    );
  }

  Widget _buildReport() {
    final grade = (_summary!['grade'] ?? 'N/A').toString();
    final score = (_summary!['score'] ?? 0).toDouble();
    final strengths = (_summary!['strengths'] as List?) ?? [];
    final weaknesses = (_summary!['weaknesses'] as List?) ?? [];

    return RefreshIndicator(
      onRefresh: _loadSummary,
      color: AppColors.blue,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _gradeColor(grade).withAlpha(30),
                    border: Border.all(color: _gradeColor(grade), width: 3),
                  ),
                  child: Center(
                    child: Text(
                      grade,
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: _gradeColor(grade),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Privacy Score: ${score.toInt()}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (strengths.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.green, size: 20),
                const SizedBox(width: 8),
                const Text('Strengths', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            ...strengths.map((s) => _buildListItem(s.toString(), AppColors.green)),
            const SizedBox(height: 20),
          ],
          if (weaknesses.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.error, color: AppColors.red, size: 20),
                const SizedBox(width: 8),
                const Text('Weaknesses', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            ...weaknesses.map((w) => _buildListItem(w.toString(), AppColors.red)),
            const SizedBox(height: 20),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _exporting ? null : _exportReport,
              icon: _exporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.download),
              label: Text(_exporting ? 'Exporting...' : 'Export Report'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListItem(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
