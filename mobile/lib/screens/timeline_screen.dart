import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../widgets/dossier.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  String? _error;
  bool _snapshotting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.getList('/timeline/score-history'),
        _api.getList('/timeline/events'),
      ]);
      setState(() {
        _history = results[0].cast<Map<String, dynamic>>();
        _events = results[1].cast<Map<String, dynamic>>();
      });
    } catch (e) {
      setState(() => _error = e is ApiException ? e.message : e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _takeSnapshot() async {
    setState(() => _snapshotting = true);
    try {
      final res = await _api.post('/timeline/snapshot?event_type=manual_check&event_description=Manual%20check');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Recorded score ${res['privacy_score']}')));
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'Could not record a snapshot')));
      }
    } finally {
      if (mounted) setState(() => _snapshotting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timeline'),
        actions: [
          IconButton(
            tooltip: 'Record score now',
            onPressed: _snapshotting ? null : _takeSnapshot,
            icon: _snapshotting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.add_chart),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.red))
          : _error != null
          ? _errorState()
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.red,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                children: [
                  const CaseHeading(code: 'Record 01', title: 'Score over time'),
                  _scoreSummary(),
                  const SizedBox(height: 12),
                  _scoreChart(),
                  CaseHeading(code: 'Record 02', title: 'Event log', trailing: Eyebrow('${_events.length} entries')),
                  if (_events.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'Nothing recorded in the last 90 days. Add accounts, run a breach scan or complete a fix and it will show up here.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  else
                    ..._groupedEvents(),
                ],
              ),
            ),
    );
  }

  Widget _errorState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const RubberStamp('Record unavailable', delay: Duration.zero),
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _loadData, child: const Text('Try again')),
        ],
      ),
    ),
  );

  Widget _scoreSummary() {
    if (_history.isEmpty) return const SizedBox();
    final first = _history.first['privacy_score'] as int;
    final last = _history.last['privacy_score'] as int;
    final delta = last - first;
    final since = DateTime.tryParse(_history.first['created_at'] ?? '')?.toLocal();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('$last', style: AppText.serif(size: 64, color: scoreColor(last))),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  delta == 0 ? 'No change' : '${delta > 0 ? '▲' : '▼'} ${delta.abs()} points',
                  style: AppText.mono(
                    size: 15,
                    weight: FontWeight.w700,
                    color: delta > 0 ? AppColors.green : delta < 0 ? AppColors.red : AppColors.textSecondary,
                  ),
                ),
                if (since != null) Eyebrow('since ${DateFormat('d MMM yyyy').format(since)} · ${_history.length} records'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _scoreChart() {
    if (_history.length < 2) {
      return FilePanel(
        child: SizedBox(
          height: 110,
          child: Center(
            child: Text(
              _history.isEmpty
                  ? 'No score recorded yet.'
                  : 'One record so far. The chart draws itself as your score changes. Complete a fix to see it move.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }
    final spots = [
      for (var i = 0; i < _history.length; i++) FlSpot(i.toDouble(), (_history[i]['privacy_score'] as int).toDouble()),
    ];
    return FilePanel(
      padding: const EdgeInsets.fromLTRB(8, 18, 18, 8),
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: 100,
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: 25,
              getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  interval: (_history.length / 4).ceilToDouble().clamp(1, double.infinity),
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    final t = i >= 0 && i < _history.length ? DateTime.tryParse(_history[i]['created_at'] ?? '') : null;
                    return Text(t == null ? '' : DateFormat('d MMM').format(t.toLocal()), style: AppText.mono(size: 9, color: AppColors.textMuted));
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: 25,
                  getTitlesWidget: (v, _) => Text('${v.toInt()}', style: AppText.mono(size: 9, color: AppColors.textMuted)),
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => AppColors.ink,
                getTooltipItems: (spots) => spots
                    .map((s) => LineTooltipItem('${s.y.toInt()}', AppText.mono(size: 12, color: AppColors.background, weight: FontWeight.w700)))
                    .toList(),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                color: AppColors.ink,
                barWidth: 2.5,
                isStepLineChart: true,
                dotData: FlDotData(
                  getDotPainter: (spot, _, _, _) => FlDotSquarePainter(
                    size: 7,
                    color: scoreColor(spot.y),
                    strokeWidth: 0,
                  ),
                ),
                belowBarData: BarAreaData(show: true, color: AppColors.ink.withAlpha(14)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _groupedEvents() {
    final widgets = <Widget>[];
    String? currentDay;
    for (final e in _events) {
      final t = DateTime.tryParse(e['date'] ?? '')?.toLocal();
      final day = t == null ? 'Undated' : DateFormat('EEEE, d MMMM').format(t);
      if (day != currentDay) {
        currentDay = day;
        widgets.add(Padding(padding: const EdgeInsets.only(top: 16, bottom: 6), child: Eyebrow(day, color: AppColors.textSecondary)));
      }
      widgets.add(_eventRow(e, t));
    }
    return widgets;
  }

  Widget _eventRow(Map<String, dynamic> e, DateTime? t) {
    final (icon, color) = switch (e['type']) {
      'breach' => (Icons.warning_amber_rounded, AppColors.red),
      'fix_completed' => (Icons.check, AppColors.green),
      'score_change' => (e['severity'] == 'success' ? Icons.trending_up : Icons.trending_down,
          e['severity'] == 'success' ? AppColors.green : AppColors.orange),
      'account_added' => (Icons.add, AppColors.ink),
      _ => (Icons.receipt_long_outlined, AppColors.textSecondary),
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 44,
            child: Text(t == null ? '' : DateFormat('HH:mm').format(t), style: AppText.mono(size: 11, color: AppColors.textMuted)),
          ),
          // Vertical rule with a square marker, like entries in a ledger.
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                color: color,
                child: Icon(icon, size: 14, color: AppColors.background),
              ),
              Expanded(child: Container(width: 1.5, color: AppColors.border)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e['title'] ?? 'Event', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  if (e['description'] != null) ...[
                    const SizedBox(height: 2),
                    Text(e['description'], style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
