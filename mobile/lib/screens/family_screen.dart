import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';
import '../services/api_service.dart';

const _device = MethodChannel('privacyshield/device');

String _errorText(Object e) => e is ApiException ? e.message : e.toString();

Color _scoreColor(num score) => score >= 80
    ? AppColors.green
    : score >= 60
    ? AppColors.blue
    : score >= 40
    ? AppColors.orange
    : AppColors.red;

void _toast(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

/// Opens the system share sheet, falling back to copying when sharing isn't available.
Future<void> shareInvite(BuildContext context, String groupName, String code) async {
  final text =
      'Join my PrivacyShield group "$groupName" so we can keep each other safe online.\n\n'
      'Open PrivacyShield → Family Shield → Join, and enter code: $code';
  try {
    await _device.invokeMethod('shareText', {'text': text, 'subject': 'PrivacyShield invite'});
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) _toast(context, 'Invite copied. Paste it into any chat.');
  }
}

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late final TabController _tabCtrl = TabController(length: 2, vsync: this);
  final _codeCtrl = TextEditingController();
  List<dynamic> _groups = [];
  bool _loading = true;
  String? _loadError;
  bool _joining = false;
  String _joinShare = 'summary';

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final data = await _api.getList('/family/groups');
      if (mounted) setState(() => _groups = data);
    } catch (e) {
      if (mounted) setState(() => _loadError = _errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _join() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() => _joining = true);
    try {
      final res = await _api.post('/family/join', body: {'invite_code': code, 'share_level': _joinShare});
      _codeCtrl.clear();
      if (!mounted) return;
      _toast(context, 'You joined ${res['group_name']}');
      await _loadGroups();
      _tabCtrl.animateTo(0);
      final group = res['group'];
      if (group != null && mounted) _open(group);
    } catch (e) {
      if (mounted) _toast(context, _errorText(e));
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _open(dynamic group) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: group['id'])));
    _loadGroups();
  }

  void _showCreateSheet() {
    final nameCtrl = TextEditingController();
    String type = 'family';
    bool saving = false;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Create a group', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text(
                "You'll get an invite code to share. You're the owner and can make others guardians.",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Group name',
                  hintText: 'e.g. The Sharmas',
                  prefixIcon: Icon(Icons.group, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(
                  labelText: 'Group type',
                  prefixIcon: Icon(Icons.category, color: AppColors.textMuted),
                ),
                dropdownColor: AppColors.surface,
                items: const [
                  DropdownMenuItem(value: 'family', child: Text('Family')),
                  DropdownMenuItem(value: 'friends', child: Text('Friends')),
                  DropdownMenuItem(value: 'team', child: Text('Team')),
                  DropdownMenuItem(value: 'organization', child: Text('Organization')),
                ],
                onChanged: (v) => setSheet(() => type = v ?? 'family'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (nameCtrl.text.trim().isEmpty) return;
                        setSheet(() => saving = true);
                        try {
                          final group = await _api.post(
                            '/family/groups',
                            body: {'name': nameCtrl.text.trim(), 'group_type': type},
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          await _loadGroups();
                          if (mounted) _open(group);
                        } catch (e) {
                          setSheet(() => saving = false);
                          if (mounted) _toast(context, _errorText(e));
                        }
                      },
                child: Text(saving ? 'Creating…' : 'Create group'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Shield'),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.blue,
          labelColor: AppColors.blue,
          unselectedLabelColor: AppColors.textMuted,
          tabs: const [Tab(text: 'My groups'), Tab(text: 'Join with code')],
        ),
      ),
      body: TabBarView(controller: _tabCtrl, children: [_groupsTab(), _joinTab()]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        onPressed: _showCreateSheet,
        icon: const Icon(Icons.add),
        label: const Text('New group'),
      ),
    );
  }

  Widget _groupsTab() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.blue));
    if (_loadError != null) {
      return _Empty(
        icon: Icons.cloud_off,
        title: "Couldn't load your groups",
        body: _loadError!,
        action: OutlinedButton(onPressed: _loadGroups, child: const Text('Try again')),
      );
    }
    if (_groups.isEmpty) {
      return _Empty(
        icon: Icons.shield_outlined,
        title: 'Protect your family together',
        body:
            "Create a group and share its invite code. Everyone keeps their own account; "
            "you see each other's privacy score, who needs help, and risks you share.",
        action: Wrap(
          spacing: 8,
          children: [
            ElevatedButton(onPressed: _showCreateSheet, child: const Text('Create a group')),
            OutlinedButton(onPressed: () => _tabCtrl.animateTo(1), child: const Text('I have a code')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadGroups,
      color: AppColors.blue,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: _groups.length,
        itemBuilder: (_, i) {
          final g = _groups[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              onTap: () => _open(g),
              leading: CircleAvatar(
                backgroundColor: AppColors.green.withAlpha(30),
                child: const Icon(Icons.groups, color: AppColors.green),
              ),
              title: Text(g['name'] ?? 'Group', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${g['member_count']} member${g['member_count'] == 1 ? '' : 's'} · ${g['group_type']} · you are ${g['my_role']}',
              ),
              trailing: g['invite_code'] != null
                  ? IconButton(
                      tooltip: 'Share invite',
                      icon: const Icon(Icons.person_add_alt_1, color: AppColors.blue),
                      onPressed: () => shareInvite(context, g['name'], g['invite_code']),
                    )
                  : const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ),
          );
        },
      ),
    );
  }

  Widget _joinTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.group_add, size: 56, color: AppColors.purple),
        const SizedBox(height: 16),
        const Text(
          'Join a group',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Ask the group owner or a guardian for the 8-character invite code.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _codeCtrl,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(letterSpacing: 4, fontWeight: FontWeight.w600, fontSize: 18),
          decoration: const InputDecoration(
            labelText: 'Invite code',
            hintText: 'ABCD2345',
            prefixIcon: Icon(Icons.vpn_key, color: AppColors.textMuted),
          ),
          onSubmitted: (_) => _join(),
        ),
        const SizedBox(height: 20),
        const Text('What the group can see about you', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _ShareChoice(value: _joinShare, onChanged: (v) => setState(() => _joinShare = v)),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _joining ? null : _join,
          child: Text(_joining ? 'Joining…' : 'Join group'),
        ),
      ],
    );
  }
}

class _ShareChoice extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _ShareChoice({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'summary', icon: Icon(Icons.visibility_outlined), label: Text('Summary')),
            ButtonSegment(value: 'detailed', icon: Icon(Icons.manage_search), label: Text('Detailed')),
          ],
          selected: {value},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
        const SizedBox(height: 6),
        Text(
          value == 'summary'
              ? 'Your score and counts only (e.g. "2 breached accounts"). Account names stay private.'
              : 'Also which accounts are at risk and why, so guardians can help with specifics.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  const _Empty({required this.icon, required this.title, required this.body, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

class GroupDetailScreen extends StatefulWidget {
  final int groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;

  int get _id => widget.groupId;
  Map<String, dynamic> get _group => _data!['group'];
  bool get _canManage => _group['my_role'] == 'owner' || _group['my_role'] == 'guardian';
  bool get _isOwner => _group['my_role'] == 'owner';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _api.get('/family/dashboard/$_id');
      if (mounted) {
        setState(() {
          _data = data;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = _errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    try {
      await action();
      if (mounted && success != null) _toast(context, success);
      await _load();
    } catch (e) {
      if (mounted) _toast(context, _errorText(e));
    }
  }

  Future<bool> _confirm(String title, String body, String action) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(action, style: const TextStyle(color: AppColors.red)),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _leave() async {
    final owner = _isOwner;
    if (!await _confirm(
      'Leave ${_group['name']}?',
      owner
          ? 'Ownership passes to a guardian, or the longest-standing member. If you are the only member the group is deleted.'
          : 'The group will no longer see your privacy snapshot.',
      'Leave',
    )) {
      return;
    }
    try {
      await _api.post('/family/groups/$_id/leave');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _toast(context, _errorText(e));
    }
  }

  Future<void> _deleteGroup() async {
    if (!await _confirm('Delete ${_group['name']}?', 'Everyone is removed and the invite code stops working.', 'Delete')) {
      return;
    }
    try {
      await _api.delete('/family/groups/$_id');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _toast(context, _errorText(e));
    }
  }

  Future<void> _nudge(Map<String, dynamic> member, {String? topic}) async {
    final topics = (_data!['nudge_topics'] as List).cast<Map<String, dynamic>>();
    String selected = topic ?? topics.first['id'];
    final msgCtrl = TextEditingController();
    final send = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Nudge ${member['display_name']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text(
                'They get a notification in PrivacyShield.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              RadioGroup<String>(
                groupValue: selected,
                onChanged: (v) => setSheet(() => selected = v!),
                child: Column(
                  children: topics
                      .map(
                        (t) => RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: t['id'],
                          title: Text(t['title']),
                        ),
                      )
                      .toList(),
                ),
              ),
              TextField(
                controller: msgCtrl,
                maxLength: 500,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: selected == 'custom' ? 'Message' : 'Add a personal note (optional)',
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.send),
                label: const Text('Send nudge'),
              ),
            ],
          ),
        ),
      ),
    );
    if (send != true) return;
    await _run(
      () => _api.post(
        '/family/groups/$_id/nudge',
        body: {
          'member_user_id': member['user_id'],
          'topic': selected,
          if (msgCtrl.text.trim().isNotEmpty) 'message': msgCtrl.text.trim(),
        },
      ),
      success: 'Nudge sent to ${member['display_name']}',
    );
  }

  void _showMember(Map<String, dynamic> m) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                _Avatar(name: m['display_name'], score: m['privacy_score']),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m['is_me'] == true ? '${m['display_name']} (you)' : m['display_name'],
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${m['role']} · shares ${m['share_level']} · ${m['risk_level']} risk',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${m['privacy_score']}',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _scoreColor(m['privacy_score'])),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip('${m['total_accounts']} accounts', Icons.apps, AppColors.blue),
                _Chip('${m['accounts_at_risk']} at risk', Icons.warning_amber, AppColors.orange),
                _Chip('${m['breached_accounts']} breached', Icons.dangerous_outlined, AppColors.red),
                _Chip('${m['without_2fa']} without 2FA', Icons.lock_open, AppColors.orange),
                _Chip('${m['reused_password_groups']} reused passwords', Icons.password, AppColors.purple),
                _Chip('${m['darkweb_exposures']} dark web', Icons.travel_explore, AppColors.red),
                _Chip('${m['completed_fixes']} fixed · ${m['pending_fixes']} to do', Icons.build, AppColors.green),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Riskiest accounts', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if ((m['top_issues'] as List).isEmpty)
              Text(
                m['share_level'] == 'summary' && m['is_me'] != true
                    ? '${m['display_name']} shares a summary only, so account names stay private.'
                    : 'Nothing risky found yet.',
                style: const TextStyle(color: AppColors.textSecondary),
              )
            else
              ...(m['top_issues'] as List).map(
                (issue) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(Icons.circle, size: 12, color: _scoreColor(100 - issue['risk'])),
                  title: Text(issue['service']),
                  subtitle: Text((issue['reasons'] as List).join(' · ')),
                  trailing: Text('risk ${issue['risk']}'),
                ),
              ),
            const SizedBox(height: 16),
            if (_canManage && m['is_me'] != true)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _nudge(m);
                },
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('Send a nudge'),
              ),
            if (_isOwner && m['is_me'] != true) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  final role = m['role'] == 'guardian' ? 'member' : 'guardian';
                  _run(
                    () => _api.patch('/family/groups/$_id/members/${m['user_id']}', body: {'role': role}),
                    success: '${m['display_name']} is now a $role',
                  );
                },
                icon: const Icon(Icons.admin_panel_settings_outlined),
                label: Text(m['role'] == 'guardian' ? 'Make regular member' : 'Make guardian'),
              ),
              TextButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  if (await _confirm('Remove ${m['display_name']}?', 'They can rejoin only with a new invite.', 'Remove')) {
                    _run(
                      () => _api.delete('/family/groups/$_id/members/${m['user_id']}'),
                      success: '${m['display_name']} removed',
                    );
                  }
                },
                icon: const Icon(Icons.person_remove, color: AppColors.red),
                label: const Text('Remove from group', style: TextStyle(color: AppColors.red)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_data?['group']?['name'] ?? 'Group'),
        actions: [
          if (_data != null)
            PopupMenuButton<String>(
              color: AppColors.surface,
              onSelected: (v) {
                if (v == 'leave') _leave();
                if (v == 'delete') _deleteGroup();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'leave', child: Text('Leave group')),
                if (_isOwner)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete group', style: TextStyle(color: AppColors.red)),
                  ),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.blue))
          : _data == null
          ? _Empty(
              icon: Icons.cloud_off,
              title: "Couldn't load this group",
              body: _error ?? '',
              action: OutlinedButton(onPressed: _load, child: const Text('Try again')),
            )
          : RefreshIndicator(onRefresh: _load, color: AppColors.blue, child: _content()),
    );
  }

  Widget _content() {
    final s = _data!['summary'];
    final members = (_data!['members'] as List).cast<Map<String, dynamic>>();
    final recs = (_data!['recommendations'] as List).cast<Map<String, dynamic>>();
    final shared = (_data!['shared_risks'] as List).cast<Map<String, dynamic>>();
    final activity = (_data!['activity'] as List).cast<Map<String, dynamic>>();
    final byId = {for (final m in members) m['user_id']: m};

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        _Panel(
          child: Column(
            children: [
              const Text('Family privacy score', style: TextStyle(color: AppColors.textSecondary)),
              Text(
                s['members_not_tracking'] == s['member_count'] ? '–' : '${s['average_score']}',
                style: TextStyle(fontSize: 56, fontWeight: FontWeight.bold, color: _scoreColor(s['average_score'])),
              ),
              if (s['members_not_tracking'] > 0)
                Text(
                  '${s['members_not_tracking']} member(s) have no accounts tracked yet',
                  style: const TextStyle(color: AppColors.orange, fontSize: 12),
                ),
              Text(
                s['members_needing_help'] > 0
                    ? '${s['members_needing_help']} of ${s['member_count']} need help'
                        '${s['weakest_member'] != null ? ' · lowest: ${s['weakest_member']}' : ''}'
                    : 'Everyone is in good shape',
                style: const TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _Stat('${s['accounts_at_risk']}', 'at risk', AppColors.orange),
                  _Stat('${s['breached_accounts']}', 'breached', AppColors.red),
                  _Stat('${s['accounts_without_2fa']}', 'no 2FA', AppColors.purple),
                  _Stat('${s['darkweb_exposures']}', 'dark web', AppColors.red),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_group['invite_code'] != null) _inviteCard(),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('What the group sees about you', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _ShareChoice(
                value: _group['my_share_level'],
                onChanged: (v) => _run(
                  () => _api.patch('/family/groups/$_id/sharing', body: {'share_level': v}),
                  success: v == 'detailed' ? 'Sharing details with the group' : 'Sharing a summary only',
                ),
              ),
            ],
          ),
        ),
        _Section('What to do next', Icons.checklist),
        if (recs.isEmpty)
          const _Muted('No open actions. Nice work, everyone.')
        else
          ...recs.map((r) {
            final target = byId[r['member_user_id']];
            final canNudge = _canManage && target != null && target['is_me'] != true;
            return _Panel(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    r['priority'] == 1 ? Icons.priority_high : Icons.arrow_forward,
                    color: r['priority'] == 1 ? AppColors.red : AppColors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r['title'], style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(r['detail'], style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  if (canNudge)
                    TextButton(onPressed: () => _nudge(target, topic: r['topic']), child: const Text('Nudge')),
                ],
              ),
            );
          }),
        _Section('Members', Icons.people_outline),
        ...members.map(
          (m) => _Panel(
            onTap: () => _showMember(m),
            child: Row(
              children: [
                _Avatar(name: m['display_name'], score: m['privacy_score']),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m['is_me'] == true ? '${m['display_name']} (you)' : m['display_name'],
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${m['role']} · ${m['total_accounts']} accounts · ${m['breached_accounts']} breached',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _RiskBadge(m['has_scanned'] == true ? m['risk_level'] : 'no data'),
              ],
            ),
          ),
        ),
        _Section('Risks you share', Icons.hub_outlined),
        if (shared.isEmpty)
          const _Muted(
            'No services used by more than one member yet. Members sharing "Detailed" are compared.',
          )
        else
          ...shared.map(
            (r) => _Panel(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    r['breached'] ? Icons.dangerous_outlined : Icons.link,
                    color: r['breached'] ? AppColors.red : AppColors.blue,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${r['service']} · ${(r['members'] as List).join(', ')}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(r['advice'], style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        _Section('Recent activity', Icons.history),
        if (activity.isEmpty)
          const _Muted('No breaches or completed fixes in the last 30 days.')
        else
          ...activity.map(
            (a) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                a['kind'] == 'breach' ? Icons.warning_amber : Icons.check_circle_outline,
                color: a['kind'] == 'breach' ? AppColors.red : AppColors.green,
              ),
              title: Text(a['text']),
              subtitle: Text(_ago(a['at'])),
            ),
          ),
      ],
    );
  }

  Widget _inviteCard() {
    final code = _group['invite_code'] as String;
    return _Panel(
      color: AppColors.blue.withAlpha(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Invite code', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          SelectableText(
            code,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 30, letterSpacing: 6, fontWeight: FontWeight.bold, color: AppColors.blue),
          ),
          const SizedBox(height: 4),
          const Text(
            'Share it with family. They join from Family Shield → Join with code.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => shareInvite(context, _group['name'], code),
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Share'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: code));
                    if (mounted) _toast(context, 'Code copied');
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy'),
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: () async {
              if (await _confirm('Make a new code?', 'The current code stops working. People already in the group stay.', 'New code')) {
                _run(() => _api.post('/family/groups/$_id/invite-code'), success: 'New invite code ready');
              }
            },
            child: const Text('Make a new code'),
          ),
        ],
      ),
    );
  }

  String _ago(String iso) {
    final t = DateTime.tryParse(iso);
    if (t == null) return '';
    final d = DateTime.now().difference(t.toLocal());
    if (d.inDays > 0) return '${d.inDays}d ago';
    if (d.inHours > 0) return '${d.inHours}h ago';
    return '${d.inMinutes}m ago';
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? color;

  const _Panel({required this.child, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: color ?? AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(14), child: child),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;

  const _Section(this.title, this.icon);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _Muted extends StatelessWidget {
  final String text;

  const _Muted(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(color: AppColors.textMuted)),
  );
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _Stat(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ],
    ),
  );
}

class _Chip extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;

  const _Chip(this.text, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: color.withAlpha(22), borderRadius: BorderRadius.circular(20)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: color, fontSize: 12)),
      ],
    ),
  );
}

class _Avatar extends StatelessWidget {
  final String name;
  final num score;

  const _Avatar({required this.name, required this.score});

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 20,
    backgroundColor: _scoreColor(score).withAlpha(30),
    child: Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: TextStyle(color: _scoreColor(score), fontWeight: FontWeight.bold),
    ),
  );
}

class _RiskBadge extends StatelessWidget {
  final String level;

  const _RiskBadge(this.level);

  @override
  Widget build(BuildContext context) {
    final color = switch (level) {
      'critical' => AppColors.red,
      'high' => AppColors.orange,
      'medium' => AppColors.blue,
      'no data' => AppColors.textMuted,
      _ => AppColors.green,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(8)),
      child: Text(level, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}
