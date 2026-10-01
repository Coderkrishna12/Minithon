import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  final _categories = ['all', 'social', 'email', 'finance', 'cloud', 'shopping', 'gaming', 'work', 'other'];

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
    if (_filterCategory == 'all') return _accounts;
    return _accounts.where((a) => a.category == _filterCategory).toList();
  }

  Color _riskColor(double score) {
    if (score >= 75) return AppColors.red;
    if (score >= 50) return AppColors.orange;
    if (score >= 25) return AppColors.blue;
    return AppColors.green;
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'social': return Icons.people;
      case 'email': return Icons.email;
      case 'finance': return Icons.account_balance;
      case 'cloud': return Icons.cloud;
      case 'shopping': return Icons.shopping_cart;
      case 'gaming': return Icons.sports_esports;
      case 'work': return Icons.work;
      default: return Icons.apps;
    }
  }

  Future<void> _deleteAccount(int id) async {
    try {
      await _api.delete('/accounts/$id');
      _loadAccounts();
    } catch (_) {}
  }

  void _showAddAccountSheet() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String category = 'social';
    String loginMethod = 'password';
    String passwordGroup = '';
    bool has2fa = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
        side: BorderSide(color: AppColors.border, width: 1.0),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20, right: 20, top: 16,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 32,
                          height: 3,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppColors.borderHover,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Text(
                        'VAULT NEW ASSET',
                        style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Register a credential node to evaluate cascading vulnerability',
                        style: GoogleFonts.spaceGrotesk(color: AppColors.textMuted, fontSize: 12),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'SERVICE / PLATFORM', hintText: 'e.g. Google, GitHub, Proton'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailCtrl,
                        decoration: const InputDecoration(labelText: 'ASSOCIATED EMAIL / IDENTIFIER'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: category,
                        decoration: const InputDecoration(labelText: 'CLASSIFICATION'),
                        dropdownColor: AppColors.surface,
                        items: _categories.where((c) => c != 'all').map((c) {
                          return DropdownMenuItem(
                            value: c,
                            child: Text(c.toUpperCase(), style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w600)),
                          );
                        }).toList(),
                        onChanged: (v) => setSheetState(() => category = v!),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: loginMethod,
                        decoration: const InputDecoration(labelText: 'AUTHENTICATION VECTOR'),
                        dropdownColor: AppColors.surface,
                        items: ['password', 'google_sso', 'apple_sso', 'facebook_sso', 'github_sso']
                            .map((m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(m.replaceAll('_', ' ').toUpperCase(), style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w600)),
                                ))
                            .toList(),
                        onChanged: (v) => setSheetState(() => loginMethod = v!),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        onChanged: (v) => passwordGroup = v,
                        decoration: const InputDecoration(labelText: 'PASSWORD COHORT (OPTIONAL)', hintText: 'Shared credential cluster label'),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.border, width: 1.0),
                        ),
                        child: SwitchListTile(
                          title: Text('TWO-FACTOR AUTHENTICATION (2FA)', style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                          subtitle: Text(has2fa ? 'ACTIVE HARDENING' : 'UNSECURED', style: GoogleFonts.spaceGrotesk(fontSize: 10, color: has2fa ? AppColors.green : AppColors.textMuted)),
                          value: has2fa,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (v) => setSheetState(() => has2fa = v),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () async {
                          if (nameCtrl.text.isEmpty) return;
                          try {
                            await _api.post('/accounts/', body: {
                              'service_name': nameCtrl.text,
                              'email_used': emailCtrl.text.isEmpty ? null : emailCtrl.text,
                              'category': category,
                              'login_method': loginMethod,
                              'password_group': passwordGroup.isEmpty ? null : passwordGroup,
                              'has_2fa': has2fa,
                            });
                            if (context.mounted) Navigator.pop(ctx);
                            _loadAccounts();
                          } catch (_) {}
                        },
                        child: const Text('VAULT ASSET'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        });
      },
    );
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
              separatorBuilder: (_, i) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final selected = cat == _filterCategory;
                return GestureDetector(
                  onTap: () => setState(() => _filterCategory = cat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.textPrimary : AppColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: selected ? AppColors.textPrimary : AppColors.border, width: 1.0),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      cat.toUpperCase(),
                      style: GoogleFonts.spaceGrotesk(
                        color: selected ? AppColors.background : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.textPrimary))
                : RefreshIndicator(
                    onRefresh: _loadAccounts,
                    color: AppColors.textPrimary,
                    child: _filteredAccounts.isEmpty
                        ? ListView(children: [
                            const SizedBox(height: 100),
                            Center(child: Text('NO VAULTED ACCOUNTS', style: GoogleFonts.spaceGrotesk(color: AppColors.textMuted, fontSize: 12, letterSpacing: 1.0))),
                          ])
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filteredAccounts.length,
                            itemBuilder: (_, i) => _buildAccountCard(_filteredAccounts[i]),
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddAccountSheet,
        backgroundColor: AppColors.textPrimary,
        foregroundColor: AppColors.background,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.add, size: 22),
      ),
    );
  }

  Widget _buildAccountCard(Account account) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 1.0),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border, width: 1.0),
          ),
          child: Icon(_categoryIcon(account.category), color: AppColors.textPrimary, size: 16),
        ),
        title: Text(account.serviceName, style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text(
          account.emailUsed ?? account.category.toUpperCase(),
          style: GoogleFonts.spaceGrotesk(color: AppColors.textMuted, fontSize: 11),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (account.has2fa)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.verified_user_outlined, color: AppColors.green, size: 16),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _riskColor(account.riskScore).withAlpha(120), width: 1.0),
              ),
              child: Text(
                '${account.riskScore.toInt()}',
                style: GoogleFonts.spaceGrotesk(
                  color: _riskColor(account.riskScore),
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.textMuted, size: 20),
              color: AppColors.surface,
              onSelected: (v) {
                if (v == 'delete') _deleteAccount(account.id);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.red))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
