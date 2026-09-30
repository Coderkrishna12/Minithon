import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import 'dashboard_screen.dart';
import 'accounts_screen.dart';
import 'graph_screen.dart';
import 'breaches_screen.dart';
import 'ai_chat_screen.dart';
import 'blockchain_screen.dart';
import 'badges_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  int _unreadCount = 0;
  final _api = ApiService();

  final _screens = const [
    DashboardScreen(),
    AccountsScreen(),
    GraphScreen(),
    BreachesScreen(),
    AiChatScreen(),
    BlockchainScreen(),
    BadgesScreen(),
  ];

  final _titles = [
    'Dashboard',
    'Accounts',
    'Account Graph',
    'Breaches',
    'PrivacyBot',
    'Blockchain',
    'Features',
  ];

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final data = await _api.get('/notifications/count');
      setState(() => _unreadCount = data['unread_count'] ?? 0);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        leading: Padding(
          padding: const EdgeInsets.all(10),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [AppColors.blue, AppColors.purple]),
            ),
            child: const Icon(Icons.shield, size: 20, color: Colors.white),
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {
                  Navigator.pushNamed(context, '/notifications').then((_) => _loadUnreadCount());
                },
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$_unreadCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            color: AppColors.surface,
            onSelected: (v) {
              if (v == 'logout') {
                context.read<AuthProvider>().logout();
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: AppColors.red, size: 18),
                    SizedBox(width: 8),
                    Text('Logout', style: TextStyle(color: AppColors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex > 4 ? 4 : _currentIndex,
        onTap: (i) {
          if (i == 4) {
            _showMoreMenu();
          } else {
            setState(() => _currentIndex = i);
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.apps), label: 'Accounts'),
          BottomNavigationBarItem(icon: Icon(Icons.hub), label: 'Graph'),
          BottomNavigationBarItem(icon: Icon(Icons.radar), label: 'Breaches'),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }

  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.3,
            maxChildSize: 0.85,
            expand: false,
            builder: (_, scrollCtrl) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: ListView(
                  controller: scrollCtrl,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.textMuted,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    _moreNavItem(Icons.password, 'Password Leak Check', AppColors.red, '/leak-check'),
                    _moreItem(Icons.smart_toy, 'PrivacyBot', AppColors.blue, 4),
                    _moreItem(Icons.link, 'Blockchain', AppColors.purple, 5),
                    _moreItem(Icons.military_tech, 'Badges & Features', AppColors.pink, 6),
                    const Divider(color: AppColors.border, height: 24),
                    _moreNavItem(Icons.timeline, 'Timeline', AppColors.cyan, '/timeline'),
                    _moreNavItem(Icons.group, 'Family Shield', AppColors.green, '/family'),
                    _moreNavItem(Icons.search, 'Search', AppColors.blue, '/search'),
                    _moreNavItem(Icons.assessment, 'Reports', AppColors.purple, '/reports'),
                    _moreNavItem(Icons.fingerprint, 'DID Identity', AppColors.cyan, '/did'),
                    _moreNavItem(Icons.how_to_vote, 'DAO Voting', AppColors.orange, '/dao'),
                    _moreNavItem(Icons.dark_mode, 'Dark Web Monitor', AppColors.red, '/darkweb'),
                    _moreNavItem(Icons.download, 'Smart Import', AppColors.green, '/smart-import'),
                    _moreNavItem(Icons.alarm, 'Reminders', AppColors.orange, '/reminders'),
                    _moreNavItem(Icons.qr_code_scanner, 'AR Scanner', AppColors.cyan, '/ar-scanner'),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _moreItem(IconData icon, String label, Color color, int index) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
      onTap: () {
        Navigator.pop(context);
        setState(() => _currentIndex = index);
      },
    );
  }

  Widget _moreNavItem(IconData icon, String label, Color color, String route) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
      onTap: () {
        Navigator.pop(context);
        Navigator.pushNamed(context, route);
      },
    );
  }
}
