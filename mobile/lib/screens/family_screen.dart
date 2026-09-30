import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/api_service.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tabCtrl;
  List<dynamic> _groups = [];
  bool _loading = true;
  final _inviteCodeCtrl = TextEditingController();
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadGroups();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _inviteCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    setState(() => _loading = true);
    try {
      final data = await _api.get('/family/groups');
      setState(() {
        _groups = (data['groups'] as List?) ?? [];
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _joinGroup() async {
    if (_inviteCodeCtrl.text.trim().isEmpty) return;
    setState(() => _joining = true);
    try {
      await _api.post('/family/join', body: {'invite_code': _inviteCodeCtrl.text.trim()});
      _inviteCodeCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully joined group')),
        );
      }
      _loadGroups();
      _tabCtrl.animateTo(0);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join: $e')),
        );
      }
    }
    setState(() => _joining = false);
  }

  void _showCreateGroupSheet() {
    final nameCtrl = TextEditingController();
    String selectedType = 'family';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Create Group',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Group Name',
                      prefixIcon: Icon(Icons.group, color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Group Type',
                      prefixIcon: Icon(Icons.category, color: AppColors.textMuted),
                    ),
                    dropdownColor: AppColors.surface,
                    items: const [
                      DropdownMenuItem(value: 'family', child: Text('Family')),
                      DropdownMenuItem(value: 'friends', child: Text('Friends')),
                      DropdownMenuItem(value: 'team', child: Text('Team')),
                      DropdownMenuItem(value: 'organization', child: Text('Organization')),
                    ],
                    onChanged: (v) => setSheetState(() => selectedType = v ?? 'family'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      try {
                        await _api.post('/family/groups', body: {
                          'name': nameCtrl.text.trim(),
                          'type': selectedType,
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                        _loadGroups();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to create group: $e')),
                          );
                        }
                      }
                    },
                    child: const Text('Create Group'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showGroupDetails(dynamic group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _GroupDetailScreen(group: group),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Family Shield')),
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
                Tab(text: 'My Groups'),
                Tab(text: 'Join Group'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [_buildGroupsTab(), _buildJoinTab()],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.blue,
        onPressed: _showCreateGroupSheet,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildGroupsTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.blue));
    }
    if (_groups.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group_off, size: 48, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text('No groups yet', style: TextStyle(color: AppColors.textMuted)),
            SizedBox(height: 4),
            Text('Create or join a group to get started', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadGroups,
      color: AppColors.blue,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _groups.length,
        itemBuilder: (_, i) {
          final group = _groups[i];
          return GestureDetector(
            onTap: () => _showGroupDetails(group),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.green.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.group, color: AppColors.green, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group['name'] ?? 'Unnamed Group',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${group['member_count'] ?? 0} members  |  ${group['type'] ?? 'group'}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textMuted),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildJoinTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.purple.withAlpha(30),
            ),
            child: const Icon(Icons.group_add, size: 48, color: AppColors.purple),
          ),
          const SizedBox(height: 24),
          const Text(
            'Join a Group',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter an invite code to join an existing group',
            style: TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _inviteCodeCtrl,
            decoration: const InputDecoration(
              labelText: 'Invite Code',
              prefixIcon: Icon(Icons.vpn_key, color: AppColors.textMuted),
              hintText: 'e.g. ABC123',
            ),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _joining ? null : _joinGroup,
              child: _joining
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Join Group'),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupDetailScreen extends StatefulWidget {
  final dynamic group;

  const _GroupDetailScreen({required this.group});

  @override
  State<_GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<_GroupDetailScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _details;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      final groupId = widget.group['id'];
      final data = await _api.get('/family/groups/$groupId');
      setState(() {
        _details = data;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.group['name'] ?? 'Group')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.blue))
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final members = (_details?['members'] as List?) ?? [];
    final avgScore = (_details?['average_score'] ?? 0).toDouble();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              const Text('Group Average Score', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Text(
                '${avgScore.toInt()}',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: avgScore >= 70 ? AppColors.green : avgScore >= 40 ? AppColors.orange : AppColors.red,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${members.length} members',
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('Members', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...members.map((member) {
          final score = (member['privacy_score'] ?? member['score'] ?? 0).toDouble();
          final color = score >= 70 ? AppColors.green : score >= 40 ? AppColors.orange : AppColors.red;
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
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.blue.withAlpha(30),
                  child: Text(
                    (member['name'] ?? member['email'] ?? '?')[0].toUpperCase(),
                    style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member['name'] ?? member['email'] ?? 'Member',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (member['role'] != null)
                        Text(
                          member['role'],
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${score.toInt()}',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
