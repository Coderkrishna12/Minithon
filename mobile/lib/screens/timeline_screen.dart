import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/api_service.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final _api = ApiService();
  List<dynamic> _scoreHistory = [];
  List<dynamic> _events = [];
  bool _loading = true;
  bool _snapshotting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.getList('/timeline/score-history'),
        _api.getList('/timeline/events'),
      ]);
      setState(() {
        _scoreHistory = results[0];
        _events = results[1];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _takeSnapshot() async {
    setState(() => _snapshotting = true);
    try {
      await _api.post('/timeline/snapshot');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Snapshot saved successfully')),
        );
      }
      _loadData();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save snapshot')),
        );
      }
    }
    setState(() => _snapshotting = false);
  }

  Color _severityColor(String? severity) {
    switch (severity) {
      case 'critical':
        return AppColors.red;
      case 'warning':
        return AppColors.orange;
      case 'info':
      default:
        return AppColors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.blue),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.blue,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Score History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: _snapshotting ? null : _takeSnapshot,
                icon: _snapshotting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.camera_alt, size: 18),
                label: Text(_snapshotting ? 'Saving...' : 'Snapshot'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildScoreChart(),
          const SizedBox(height: 24),
          const Text(
            'Events',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (_events.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No events yet',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            )
          else
            ..._events.map((event) => _buildEventCard(event)),
        ],
      ),
    );
  }

  Widget _buildScoreChart() {
    if (_scoreHistory.isEmpty) {
      return Container(
        height: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Text(
            'No score history available',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    final maxScore = _scoreHistory.fold<double>(0, (max, item) {
      final score = (item['score'] ?? 0).toDouble();
      return score > max ? score : max;
    });
    final chartMax = maxScore > 0 ? maxScore : 100.0;

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
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _scoreHistory.map((item) {
                final score = (item['score'] ?? 0).toDouble();
                final height = chartMax > 0 ? (score / chartMax) * 100 : 0.0;
                final color = score >= 70
                    ? AppColors.green
                    : score >= 40
                    ? AppColors.orange
                    : AppColors.red;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${score.toInt()}',
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: height,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(dynamic event) {
    final severity = event['severity'] as String? ?? 'info';
    final color = _severityColor(severity);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event['title'] ?? event['event_type'] ?? 'Event',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (event['description'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    event['description'],
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (event['timestamp'] != null ||
                    event['created_at'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    event['timestamp'] ?? event['created_at'] ?? '',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              severity,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
