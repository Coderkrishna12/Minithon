import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/api_service.dart';

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tabCtrl;
  List<dynamic> _badges = [];
  List<dynamic> _brokers = [];
  bool _loadingBadges = true;
  bool _loadingBrokers = true;
  bool _lockdownTriggered = false;

  final _badgeTypes = [
    {'type': 'privacy_pioneer', 'title': 'Privacy Pioneer', 'desc': 'First audit completed', 'icon': Icons.explore, 'color': AppColors.blue},
    {'type': 'two_fa_champion', 'title': '2FA Champion', 'desc': '2FA on all accounts', 'icon': Icons.verified_user, 'color': AppColors.green},
    {'type': 'breach_survivor', 'title': 'Breach Survivor', 'desc': 'Survived a breach scan', 'icon': Icons.shield, 'color': AppColors.orange},
    {'type': 'graph_master', 'title': 'Graph Master', 'desc': '10+ connected accounts', 'icon': Icons.hub, 'color': AppColors.purple},
    {'type': 'fix_hero', 'title': 'Fix Hero', 'desc': 'All fixes completed', 'icon': Icons.build, 'color': AppColors.cyan},
    {'type': 'blockchain_verified', 'title': 'Blockchain Verified', 'desc': 'ZKP certificate generated', 'icon': Icons.link, 'color': AppColors.pink},
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadBadges();
    _loadBrokers();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBadges() async {
    try {
      final data = await _api.getList('/features/badges');
      setState(() {
        _badges = data;
        _loadingBadges = false;
      });
    } catch (_) {
      setState(() => _loadingBadges = false);
    }
  }

  Future<void> _loadBrokers() async {
    try {
      final data = await _api.getList('/features/data-brokers');
      setState(() {
        _brokers = data;
        _loadingBrokers = false;
      });
    } catch (_) {
      setState(() => _loadingBrokers = false);
    }
  }

  Future<void> _mintBadge(String type) async {
    try {
      await _api.post('/features/badges/mint/$type');
      _loadBadges();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Badge minted!'), backgroundColor: AppColors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.red),
        );
      }
    }
  }

  Future<void> _triggerLockdown() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Emergency Lockdown'),
        content: const Text('This will attempt to lock down all connected accounts. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('LOCKDOWN'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.post('/features/lockdown');
      setState(() => _lockdownTriggered = true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AppColors.surface,
          child: TabBar(
            controller: _tabCtrl,
            indicatorColor: AppColors.pink,
            labelColor: AppColors.pink,
            unselectedLabelColor: AppColors.textMuted,
            tabs: const [
              Tab(text: 'NFT Badges'),
              Tab(text: 'Death Switch'),
              Tab(text: 'Data Brokers'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [_buildBadgesTab(), _buildDeathSwitchTab(), _buildBrokersTab()],
          ),
        ),
      ],
    );
  }

  Widget _buildBadgesTab() {
    if (_loadingBadges) return const Center(child: CircularProgressIndicator(color: AppColors.pink));
    final mintedTypes = _badges.map((b) => b['badge_type']).toSet();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: _badgeTypes.map((bt) {
        final minted = mintedTypes.contains(bt['type']);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: minted ? (bt['color'] as Color).withAlpha(120) : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (bt['color'] as Color).withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(bt['icon'] as IconData, color: bt['color'] as Color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bt['title'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(bt['desc'] as String, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              if (minted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.green.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Minted', style: TextStyle(color: AppColors.green, fontSize: 12, fontWeight: FontWeight.w600)),
                )
              else
                TextButton(
                  onPressed: () => _mintBadge(bt['type'] as String),
                  child: const Text('Mint', style: TextStyle(color: AppColors.pink)),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDeathSwitchTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _lockdownTriggered ? AppColors.green.withAlpha(30) : AppColors.red.withAlpha(30),
                border: Border.all(
                  color: _lockdownTriggered ? AppColors.green : AppColors.red,
                  width: 3,
                ),
              ),
              child: Icon(
                _lockdownTriggered ? Icons.check : Icons.power_settings_new,
                size: 56,
                color: _lockdownTriggered ? AppColors.green : AppColors.red,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _lockdownTriggered ? 'Lockdown Activated' : 'Emergency Lockdown',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _lockdownTriggered
                  ? 'All accounts have been locked down. Follow recovery steps below.'
                  : 'One tap to lock down your entire digital life',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            if (!_lockdownTriggered)
              GestureDetector(
                onTap: _triggerLockdown,
                child: Container(
                  width: 200,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.red,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'ACTIVATE LOCKDOWN',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              )
            else ...[
              const Text('Recovery Steps:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...[
                '1. Change your primary email password',
                '2. Enable 2FA on all accounts',
                '3. Revoke suspicious app permissions',
                '4. Check breach scanner results',
              ].map((step) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.chevron_right, color: AppColors.green, size: 18),
                        const SizedBox(width: 4),
                        Flexible(child: Text(step, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBrokersTab() {
    if (_loadingBrokers) return const Center(child: CircularProgressIndicator(color: AppColors.pink));
    if (_brokers.isEmpty) {
      return const Center(child: Text('No data brokers found', style: TextStyle(color: AppColors.textMuted)));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () async {
              try {
                await _api.post('/features/data-brokers/opt-out-all');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Opt-out requests sent!'), backgroundColor: AppColors.green),
                  );
                }
              } catch (_) {}
            },
            icon: const Icon(Icons.block),
            label: const Text('Opt-Out All'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.pink,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _brokers.length,
            itemBuilder: (_, i) {
              final b = _brokers[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.visibility_off, color: AppColors.pink, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(b['category'] ?? '', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: b['opted_out'] == true ? AppColors.green.withAlpha(30) : AppColors.orange.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        b['opted_out'] == true ? 'Opted Out' : 'Active',
                        style: TextStyle(
                          color: b['opted_out'] == true ? AppColors.green : AppColors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
