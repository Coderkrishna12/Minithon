import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/api_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _api = ApiService();
  final _searchCtrl = TextEditingController();
  Map<String, dynamic>? _results;
  bool _loading = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _loading = true;
      _hasSearched = true;
    });
    try {
      final data = await _api.get('/search?q=$query');
      setState(() {
        _results = data;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _results = null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search accounts, breaches, notifications...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send, color: AppColors.blue),
                  onPressed: _search,
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.blue));
    }

    if (!_hasSearched) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 64, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text('Search your privacy data', style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
          ],
        ),
      );
    }

    if (_results == null) {
      return const Center(
        child: Text('Something went wrong', style: TextStyle(color: AppColors.textMuted)),
      );
    }

    final accounts = (_results!['accounts'] as List?) ?? [];
    final breaches = (_results!['breaches'] as List?) ?? [];
    final notifications = (_results!['notifications'] as List?) ?? [];

    if (accounts.isEmpty && breaches.isEmpty && notifications.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text('No results found', style: TextStyle(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        if (accounts.isNotEmpty) ...[
          _buildSectionHeader('Accounts', Icons.apps, AppColors.blue, accounts.length),
          ...accounts.map((a) => _buildResultItem(
                a['service_name'] ?? a['title'] ?? 'Account',
                a['email'] ?? a['subtitle'] ?? '',
                Icons.apps,
                AppColors.blue,
              )),
          const SizedBox(height: 16),
        ],
        if (breaches.isNotEmpty) ...[
          _buildSectionHeader('Breaches', Icons.warning_amber, AppColors.red, breaches.length),
          ...breaches.map((b) => _buildResultItem(
                b['breach_name'] ?? b['title'] ?? 'Breach',
                b['service_name'] ?? b['subtitle'] ?? '',
                Icons.warning_amber,
                AppColors.red,
              )),
          const SizedBox(height: 16),
        ],
        if (notifications.isNotEmpty) ...[
          _buildSectionHeader('Notifications', Icons.notifications, AppColors.orange, notifications.length),
          ...notifications.map((n) => _buildResultItem(
                n['title'] ?? 'Notification',
                n['message'] ?? n['subtitle'] ?? '',
                Icons.notifications,
                AppColors.orange,
              )),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(String title, String subtitle, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
