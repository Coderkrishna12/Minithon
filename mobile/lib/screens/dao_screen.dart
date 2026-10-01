import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/api_service.dart';

class DAOScreen extends StatefulWidget {
  const DAOScreen({super.key});

  @override
  State<DAOScreen> createState() => _DAOScreenState();
}

class _DAOScreenState extends State<DAOScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tabCtrl;
  List<dynamic> _proposals = [];
  Map<String, dynamic>? _stats;
  bool _loadingProposals = true;
  bool _loadingStats = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    _loadProposals();
    _loadStats();
  }

  Future<void> _loadProposals() async {
    setState(() => _loadingProposals = true);
    try {
      final data = await _api.getList('/dao/proposals');
      setState(() {
        _proposals = data;
        _loadingProposals = false;
      });
    } catch (_) {
      setState(() => _loadingProposals = false);
    }
  }

  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);
    try {
      final data = await _api.get('/dao/stats');
      setState(() {
        _stats = data;
        _loadingStats = false;
      });
    } catch (_) {
      setState(() => _loadingStats = false);
    }
  }

  Future<void> _vote(int proposalId, String vote) async {
    try {
      await _api.post('/dao/proposals/$proposalId/vote', body: {'vote': vote});
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Vote "$vote" recorded')));
      }
      _loadProposals();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Vote failed: $e')));
      }
    }
  }

  void _showCreateProposalSheet() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final serviceCtrl = TextEditingController();
    final dateCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Create Proposal',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: serviceCtrl,
                  decoration: const InputDecoration(labelText: 'Service Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dateCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Breach Date (YYYY-MM-DD)',
                    hintText: '2024-01-15',
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) return;
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await _api.post(
                        '/dao/proposals',
                        body: {
                          'title': titleCtrl.text.trim(),
                          'description': descCtrl.text.trim(),
                          'service_name': serviceCtrl.text.trim(),
                          'breach_date': dateCtrl.text.trim(),
                        },
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadProposals();
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Failed: $e')),
                      );
                    }
                  },
                  child: const Text('Submit Proposal'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'active':
        return AppColors.blue;
      case 'confirmed':
      case 'approved':
        return AppColors.green;
      case 'rejected':
        return AppColors.red;
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DAO Voting')),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            child: TabBar(
              controller: _tabCtrl,
              indicatorColor: AppColors.blue,
              labelColor: AppColors.blue,
              unselectedLabelColor: AppColors.textMuted,
              tabs: const [
                Tab(text: 'Proposals'),
                Tab(text: 'Stats'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [_buildProposalsTab(), _buildStatsTab()],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.blue,
        onPressed: _showCreateProposalSheet,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildProposalsTab() {
    if (_loadingProposals) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.blue),
      );
    }
    if (_proposals.isEmpty) {
      return const Center(
        child: Text(
          'No proposals yet',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProposals,
      color: AppColors.blue,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _proposals.length,
        itemBuilder: (_, i) {
          final p = _proposals[i];
          final status = p['status'] ?? 'active';
          final votesFor = (p['votes_for'] ?? 0) as int;
          final votesAgainst = (p['votes_against'] ?? 0) as int;
          final totalVotes = votesFor + votesAgainst;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        p['title'] ?? 'Untitled',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: _statusColor(status),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (p['service_name'] != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Service: ${p['service_name']}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    _voteChip(Icons.thumb_up, votesFor, AppColors.green),
                    const SizedBox(width: 12),
                    _voteChip(Icons.thumb_down, votesAgainst, AppColors.red),
                    const Spacer(),
                    Text(
                      '$totalVotes votes',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                if (totalVotes > 0) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: votesFor / totalVotes,
                      backgroundColor: AppColors.red.withAlpha(100),
                      valueColor: const AlwaysStoppedAnimation(AppColors.green),
                      minHeight: 6,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _vote(p['id'], 'for'),
                        icon: const Icon(Icons.thumb_up, size: 16),
                        label: const Text('Vote For'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.green,
                          side: const BorderSide(color: AppColors.green),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _vote(p['id'], 'against'),
                        icon: const Icon(Icons.thumb_down, size: 16),
                        label: const Text('Against'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.red,
                          side: const BorderSide(color: AppColors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _voteChip(IconData icon, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsTab() {
    if (_loadingStats) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.blue),
      );
    }
    if (_stats == null) {
      return const Center(
        child: Text(
          'Could not load stats',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStats,
      color: AppColors.blue,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _statCard(
                'Total Proposals',
                '${_stats!['total_proposals'] ?? 0}',
                Icons.description,
                AppColors.blue,
              ),
              _statCard(
                'Active',
                '${_stats!['active'] ?? _stats!['active_proposals'] ?? 0}',
                Icons.pending_actions,
                AppColors.orange,
              ),
              _statCard(
                'Confirmed',
                '${_stats!['confirmed'] ?? _stats!['confirmed_proposals'] ?? 0}',
                Icons.check_circle,
                AppColors.green,
              ),
              _statCard(
                'Total Votes',
                '${_stats!['total_votes'] ?? 0}',
                Icons.how_to_vote,
                AppColors.purple,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
