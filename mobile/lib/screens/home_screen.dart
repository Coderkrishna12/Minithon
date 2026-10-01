import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
import 'android_security_screen.dart';
import 'ar_scanner_screen.dart';

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
    AndroidSecurityScreen(),
    ARScannerScreen(),
    GraphScreen(),
    AccountsScreen(),
    BreachesScreen(),
    AiChatScreen(),
    BlockchainScreen(),
    BadgesScreen(),
  ];

  final _titles = [
    'Dashboard',
    'Android Sentry',
    'Airspace RF Radar',
    'Account Graph',
    'Accounts',
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
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.border, width: 1.0),
              ),
              child: const Text(
                'VAULT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: AppColors.titanium,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _titles[_currentIndex].toUpperCase(),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
        leading: Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border, width: 1.0),
            ),
            child: const Icon(Icons.shield_outlined, size: 16, color: AppColors.textPrimary),
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none, size: 20),
                onPressed: () {
                  Navigator.pushNamed(context, '/notifications').then((_) => _loadUnreadCount());
                },
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      '$_unreadCount',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, size: 20),
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AppColors.border, width: 1.0),
            ),
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
                    Icon(Icons.logout, color: AppColors.red, size: 16),
                    SizedBox(width: 8),
                    Text('Logout', style: TextStyle(color: AppColors.red, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: SizedBox.expand(
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
        ),
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
          BottomNavigationBarItem(icon: Icon(Icons.space_dashboard_outlined, size: 20), activeIcon: Icon(Icons.space_dashboard, size: 20), label: 'DASHBOARD'),
          BottomNavigationBarItem(icon: Icon(Icons.shield_outlined, size: 20), activeIcon: Icon(Icons.shield, size: 20), label: 'ANDROID SENTRY'),
          BottomNavigationBarItem(icon: Icon(Icons.radar_outlined, size: 20), activeIcon: Icon(Icons.radar, size: 20), label: 'AIRSPACE RF'),
          BottomNavigationBarItem(icon: Icon(Icons.polyline_outlined, size: 20), activeIcon: Icon(Icons.polyline, size: 20), label: 'GRAPH'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_outlined, size: 20), activeIcon: Icon(Icons.menu, size: 20), label: 'MORE'),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
        side: BorderSide(color: AppColors.border, width: 1.0),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: DraggableScrollableSheet(
                initialChildSize: 0.65,
                minChildSize: 0.3,
                maxChildSize: 0.9,
                expand: false,
                builder: (_, scrollCtrl) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: ListView(
                      controller: scrollCtrl,
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
                          'PRIMARY ENCLAVES',
                          style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 12),
                        _moreItem(Icons.grid_view_outlined, 'Accounts Vault', AppColors.textPrimary, 4),
                        _moreItem(Icons.warning_amber_outlined, 'Breach Feed & Matrix', AppColors.titanium, 5),
                        _moreItem(Icons.smart_toy_outlined, 'PrivacyBot AI Engine', AppColors.textPrimary, 6),
                        _moreItem(Icons.link, 'Blockchain Ledger', AppColors.titanium, 7),
                        _moreItem(Icons.military_tech_outlined, 'Badges & Leveling', AppColors.titanium, 8),
                        const Divider(color: AppColors.border, height: 24),
                        Text(
                          'HARDWARE & ENDPOINT CONTROLS',
                          style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 12),
                        _moreNavItem(Icons.security, 'Android Endpoint Sentry', AppColors.textPrimary, '/android-security'),
                        _moreNavItem(Icons.wifi_tethering, 'Airspace RF & Evil-Twin Radar', AppColors.titanium, '/ar-scanner'),
                        const Divider(color: AppColors.border, height: 24),
                        Text(
                          'PRIVACY INTEL & DEEP TOOLS',
                          style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 12),
                        _moreNavItem(Icons.timeline, 'Audit Timeline', AppColors.titanium, '/timeline'),
                        _moreNavItem(Icons.group_outlined, 'Family Perimeter', AppColors.titanium, '/family'),
                        _moreNavItem(Icons.search, 'Search Index', AppColors.titanium, '/search'),
                        _moreNavItem(Icons.assessment_outlined, 'Executive Reports', AppColors.titanium, '/reports'),
                        _moreNavItem(Icons.fingerprint, 'DID Identity Sovereign', AppColors.titanium, '/did'),
                        _moreNavItem(Icons.how_to_vote_outlined, 'DAO Governance', AppColors.titanium, '/dao'),
                        _moreNavItem(Icons.dark_mode_outlined, 'Dark Web Intelligence', AppColors.titanium, '/darkweb'),
                        _moreNavItem(Icons.download_outlined, 'Smart Ingestion', AppColors.titanium, '/smart-import'),
                        _moreNavItem(Icons.alarm, 'Policy Reminders', AppColors.titanium, '/reminders'),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _moreItem(IconData icon, String label, Color color, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border, width: 1.0),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: AppColors.textPrimary, size: 18),
        title: Text(label.toUpperCase(), style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.8)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.textMuted),
        onTap: () {
          Navigator.pop(context);
          setState(() => _currentIndex = index);
        },
      ),
    );
  }

  Widget _moreNavItem(IconData icon, String label, Color color, String route) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border, width: 1.0),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: AppColors.titanium, size: 18),
        title: Text(label.toUpperCase(), style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, fontSize: 12, letterSpacing: 0.8)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.textMuted),
        onTap: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, route);
        },
      ),
    );
  }
}
