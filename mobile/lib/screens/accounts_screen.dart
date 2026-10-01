import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../models/account.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final _api = ApiService();
  List<Account> _accounts = [];
  bool _loading = true;
  String _filterCategory = 'all';
  String _filterRisk = 'all';
  String _filterTwoFa = 'all';

  final _categories = [
    'all',
    'social',
    'email',
    'finance',
    'cloud',
    'shopping',
    'gaming',
    'work',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getList('/accounts/');
      setState(() {
        _accounts = data.map((e) => Account.fromJson(e)).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  List<Account> get _filteredAccounts {
    return _accounts.where((a) {
      if (_filterCategory != 'all' && a.category != _filterCategory) {
        return false;
      }
      if (_filterRisk != 'all' && a.riskLevel.toLowerCase() != _filterRisk) {
        return false;
      }
      if (_filterTwoFa == 'enabled' && !a.has2fa) return false;
      if (_filterTwoFa == 'disabled' && a.has2fa) return false;
      return true;
    }).toList();
  }

  Color _riskColor(double score) {
    if (score >= 75) return AppColors.red;
    if (score >= 50) return AppColors.orange;
    if (score >= 25) return AppColors.blue;
    return AppColors.green;
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'social':
        return Icons.people;
      case 'email':
        return Icons.email;
      case 'finance':
        return Icons.account_balance;
      case 'cloud':
        return Icons.cloud;
      case 'shopping':
        return Icons.shopping_cart;
      case 'gaming':
        return Icons.sports_esports;
      case 'work':
        return Icons.work;
      default:
        return Icons.apps;
    }
  }

  Future<void> _deleteAccount(int id) async {
    try {
      await _api.delete('/accounts/$id');
      _loadAccounts();
    } catch (_) {}
  }

  void _showAccountSheet([Account? existing]) {
    final nameCtrl = TextEditingController(text: existing?.serviceName ?? '');
    final urlCtrl = TextEditingController(text: existing?.serviceUrl ?? '');
    final emailCtrl = TextEditingController(text: existing?.emailUsed ?? '');
    final usernameCtrl = TextEditingController(
      text: existing?.usernameUsed ?? '',
    );
    final recoveryEmailCtrl = TextEditingController(
      text: existing?.recoveryEmail ?? '',
    );
    final recoveryPhoneCtrl = TextEditingController(
      text: existing?.recoveryPhone ?? '',
    );
    final permissionsCtrl = TextEditingController(
      text: existing?.permissions.join(', ') ?? '',
    );
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    String category = existing?.category ?? 'social';
    String loginMethod = existing?.loginMethod ?? 'password';
    String passwordGroup = existing?.passwordGroup ?? '';
    bool has2fa = existing?.has2fa ?? false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      existing == null ? 'Add Account' : 'Edit Account',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Service Name',
                        hintText: 'e.g. Google, Instagram',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: urlCtrl,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Service URL (optional)',
                        hintText: 'https://example.com',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email Used',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: usernameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Username (optional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: recoveryEmailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Recovery Email (optional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: recoveryPhoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Recovery Phone (optional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      dropdownColor: AppColors.surface,
                      items: _categories.where((c) => c != 'all').map((c) {
                        return DropdownMenuItem(
                          value: c,
                          child: Text(c[0].toUpperCase() + c.substring(1)),
                        );
                      }).toList(),
                      onChanged: (v) => setSheetState(() => category = v!),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: loginMethod,
                      decoration: const InputDecoration(
                        labelText: 'Login Method',
                      ),
                      dropdownColor: AppColors.surface,
                      items:
                          [
                                'password',
                                'google_sso',
                                'apple_sso',
                                'facebook_sso',
                                'github_sso',
                              ]
                              .map(
                                (m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(
                                    m.replaceAll('_', ' ').toUpperCase(),
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (v) => setSheetState(() => loginMethod = v!),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (v) => passwordGroup = v,
                      decoration: const InputDecoration(
                        labelText: 'Password Group (optional)',
                        hintText: 'Label for shared passwords',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: permissionsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Permissions (comma separated)',
                        hintText: 'location, contacts, camera',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('2FA Enabled'),
                      value: has2fa,
                      activeThumbColor: AppColors.green,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) => setSheetState(() => has2fa = v),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        if (nameCtrl.text.isEmpty) return;
                        try {
                          final payload = {
                            'service_name': nameCtrl.text,
                            'service_url': urlCtrl.text.trim().isEmpty
                                ? null
                                : urlCtrl.text.trim(),
                            'email_used': emailCtrl.text.isEmpty
                                ? null
                                : emailCtrl.text,
                            'username_used': usernameCtrl.text.trim().isEmpty
                                ? null
                                : usernameCtrl.text.trim(),
                            'recovery_email':
                                recoveryEmailCtrl.text.trim().isEmpty
                                ? null
                                : recoveryEmailCtrl.text.trim(),
                            'recovery_phone':
                                recoveryPhoneCtrl.text.trim().isEmpty
                                ? null
                                : recoveryPhoneCtrl.text.trim(),
                            'category': category,
                            'login_method': loginMethod,
                            'password_group': passwordGroup.isEmpty
                                ? null
                                : passwordGroup,
                            'permissions': permissionsCtrl.text
                                .split(',')
                                .map((v) => v.trim())
                                .where((v) => v.isNotEmpty)
                                .toList(),
                            'notes': notesCtrl.text.trim().isEmpty
                                ? null
                                : notesCtrl.text.trim(),
                            'has_2fa': has2fa,
                          };
                          if (existing == null) {
                            await _api.post('/accounts/', body: payload);
                          } else {
                            await _api.put(
                              '/accounts/${existing.id}',
                              body: payload,
                            );
                          }
                          if (context.mounted) Navigator.pop(ctx);
                          _loadAccounts();
                        } catch (_) {}
                      },
                      child: Text(
                        existing == null ? 'Add Account' : 'Save Changes',
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      nameCtrl.dispose();
      urlCtrl.dispose();
      emailCtrl.dispose();
      usernameCtrl.dispose();
      recoveryEmailCtrl.dispose();
      recoveryPhoneCtrl.dispose();
      permissionsCtrl.dispose();
      notesCtrl.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SizedBox(
            height: 40,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, i) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final selected = cat == _filterCategory;
                return GestureDetector(
                  onTap: () => setState(() => _filterCategory = cat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.blue : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? AppColors.blue : AppColors.border,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      cat[0].toUpperCase() + cat.substring(1),
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : AppColors.textSecondary,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: [
                _filterChip(
                  'Risk: All',
                  _filterRisk == 'all',
                  () => setState(() => _filterRisk = 'all'),
                ),
                for (final level in ['critical', 'high', 'medium', 'low'])
                  _filterChip(
                    'Risk: ${level[0].toUpperCase()}${level.substring(1)}',
                    _filterRisk == level,
                    () => setState(() => _filterRisk = level),
                  ),
                _filterChip(
                  '2FA: Any',
                  _filterTwoFa == 'all',
                  () => setState(() => _filterTwoFa = 'all'),
                ),
                _filterChip(
                  '2FA: On',
                  _filterTwoFa == 'enabled',
                  () => setState(() => _filterTwoFa = 'enabled'),
                ),
                _filterChip(
                  '2FA: Off',
                  _filterTwoFa == 'disabled',
                  () => setState(() => _filterTwoFa = 'disabled'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.blue),
                  )
                : RefreshIndicator(
                    onRefresh: _loadAccounts,
                    color: AppColors.blue,
                    child: _filteredAccounts.isEmpty
                        ? ListView(
                            children: [
                              const SizedBox(height: 100),
                              const Center(
                                child: Text(
                                  'No accounts yet',
                                  style: TextStyle(color: AppColors.textMuted),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filteredAccounts.length,
                            itemBuilder: (_, i) =>
                                _buildAccountCard(_filteredAccounts[i]),
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAccountSheet(),
        backgroundColor: AppColors.blue,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) =>
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
        ),
      );

  Widget _buildAccountCard(Account account) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _riskColor(account.riskScore).withAlpha(30),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _categoryIcon(account.category),
            color: _riskColor(account.riskScore),
          ),
        ),
        title: Text(
          account.serviceName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          account.emailUsed ?? account.category,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (account.has2fa)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.verified_user,
                  color: AppColors.green,
                  size: 18,
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _riskColor(account.riskScore).withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${account.riskScore.toInt()}',
                style: TextStyle(
                  color: _riskColor(account.riskScore),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert,
                color: AppColors.textMuted,
                size: 20,
              ),
              color: AppColors.surface,
              onSelected: (v) {
                if (v == 'delete') _deleteAccount(account.id);
                if (v == 'edit') _showAccountSheet(account);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: AppColors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
