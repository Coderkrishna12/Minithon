import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';
import '../services/api_service.dart';

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tabCtrl;
  List<dynamic> _badges = [];
  List<dynamic> _availableBadges = [];
  List<dynamic> _brokers = [];
  bool _loadingBadges = true;
  bool _loadingBrokers = true;
  bool _lockdownTriggered = false;
  List<dynamic> _recoverySteps = [];
  bool _lockingDown = false;

  final _badgeIcons = [
    Icons.shield,
    Icons.verified_user,
    Icons.password,
    Icons.cleaning_services,
    Icons.warning_amber,
    Icons.fact_check,
  ];
  final _badgeColors = [
    AppColors.blue,
    AppColors.green,
    AppColors.purple,
    AppColors.cyan,
    AppColors.orange,
    AppColors.pink,
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
      final data = await _api.get('/features/badges');
      setState(() {
        _badges = (data['minted'] as List?) ?? [];
        _availableBadges = (data['available'] as List?) ?? [];
        _loadingBadges = false;
      });
    } catch (_) {
      setState(() => _loadingBadges = false);
    }
  }

  Future<void> _loadBrokers() async {
    try {
      final data = await _api.get('/features/data-brokers');
      setState(() {
        _brokers = (data['brokers'] as List?) ?? [];
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
          const SnackBar(
            content: Text('Badge minted!'),
            backgroundColor: AppColors.green,
          ),
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
        content: const Text(
          'This will attempt to lock down all connected accounts. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('LOCKDOWN'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _lockingDown = true);
    try {
      final result = await _api.post('/features/lockdown');
      if (mounted) {
        setState(() {
          _lockdownTriggered = true;
          _recoverySteps = (result['recovery_steps'] as List?) ?? [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Lockdown plan prepared for ${result['accounts_affected'] ?? 0} accounts. Review each service action below.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not activate lockdown: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _lockingDown = false);
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
            children: [
              _buildBadgesTab(),
              _buildDeathSwitchTab(),
              _buildBrokersTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBadgesTab() {
    if (_loadingBadges) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.pink),
      );
    }
    final mintedTypes = _badges
        .map((b) => b['type'] ?? b['badge_type'])
        .toSet();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: List.generate(_availableBadges.length, (index) {
        final bt = _availableBadges[index] as Map<String, dynamic>;
        final type = bt['type'] as String;
        final color = _badgeColors[index % _badgeColors.length];
        final minted = bt['minted'] == true || mintedTypes.contains(type);
        final eligible = bt['eligible'] == true;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: minted ? color.withAlpha(120) : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _badgeIcons[index % _badgeIcons.length],
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bt['title'] as String? ?? type,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      bt['description'] as String? ?? '',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (minted)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.green.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Minted',
                    style: TextStyle(
                      color: AppColors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                TextButton(
                  onPressed: eligible ? () => _mintBadge(type) : null,
                  child: Text(
                    eligible ? 'Mint' : 'Locked',
                    style: TextStyle(
                      color: eligible ? AppColors.pink : AppColors.textMuted,
                    ),
                  ),
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
                color: _lockdownTriggered
                    ? AppColors.green.withAlpha(30)
                    : AppColors.red.withAlpha(30),
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
                  ? 'Your response plan is ready. PrivacyShield cannot revoke sessions or reset passwords on your behalf; complete these steps with each service.'
                  : 'Prepare a prioritized response plan for your connected accounts',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            if (!_lockdownTriggered)
              GestureDetector(
                onTap: _lockingDown ? null : _triggerLockdown,
                child: Container(
                  width: 200,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.red,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _lockingDown ? 'PREPARING…' : 'PREPARE LOCKDOWN',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              )
            else ...[
              const Text(
                'Recovery Steps:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ..._recoverySteps.map(
                (step) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.green,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          step,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBrokersTab() {
    if (_loadingBrokers) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.pink),
      );
    }
    if (_brokers.isEmpty) {
      return const Center(
        child: Text(
          'No data brokers found',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () async {
              try {
                final result = await _api.post(
                  '/features/data-brokers/opt-out-all',
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${result['total_brokers'] ?? _brokers.length} opt-out forms are ready. Open each broker link and submit its form to complete removal.',
                      ),
                      backgroundColor: AppColors.blue,
                    ),
                  );
                }
              } catch (_) {}
            },
            icon: const Icon(Icons.block),
            label: const Text('Get opt-out links'),
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
                    const Icon(
                      Icons.visibility_off,
                      color: AppColors.pink,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b['name'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            (b['data_types'] as List? ?? []).join(' · '),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy opt-out link',
                      icon: const Icon(
                        Icons.open_in_new,
                        color: AppColors.blue,
                      ),
                      onPressed: () async {
                        final url = b['opt_out_url']?.toString() ?? '';
                        try {
                          await const MethodChannel(
                            'privacyshield/device',
                          ).invokeMethod('openUrl', {'url': url});
                        } on PlatformException {
                          await Clipboard.setData(ClipboardData(text: url));
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Link copied. Open it and submit the broker form.',
                                ),
                              ),
                            );
                          }
                        } on MissingPluginException {
                          await Clipboard.setData(ClipboardData(text: url));
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Link copied. Open it and submit the broker form.',
                                ),
                              ),
                            );
                          }
                        }
                      },
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.blue.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Open form',
                        style: TextStyle(
                          color: AppColors.blue,
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
