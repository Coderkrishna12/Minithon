import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/biometric_service.dart';
import '../services/breach_monitor.dart';
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
import 'device_audit_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  int _unreadCount = 0;
  bool _isOffline = false;
  bool _biometricEnabled = false;
  bool _locked = false;
  bool _authInProgress = false;
  bool _monitorConnecting = false;
  bool _appResumed = true;
  Timer? _monitorTimer;
  final _api = ApiService();
  final _biometric = BiometricService();
  final _breachMonitor = BreachMonitor();

  final _screens = const [
    DashboardScreen(),
    DeviceAuditScreen(embedded: true),
    AccountsScreen(),
    BreachesScreen(),
    AiChatScreen(),
    BlockchainScreen(),
    BadgesScreen(),
    GraphScreen(),
  ];

  final _titles = [
    'Overview',
    'This phone',
    'Accounts',
    'Breaches',
    'PrivacyBot',
    'Audit log',
    'Badges',
    'Risk graph',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUnreadCount();
    _checkConnection();
    _loadBiometricSetting();
    _connectBreachMonitor();
    _monitorTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_appResumed && !_breachMonitor.connected && !_monitorConnecting) {
        _connectBreachMonitor();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _monitorTimer?.cancel();
    _breachMonitor.disconnect();
    super.dispose();
  }

  Future<void> _connectBreachMonitor() async {
    if (_monitorConnecting || _breachMonitor.connected) return;
    _monitorConnecting = true;
    try {
      final token = await _api.accessToken;
      if (token == null || token.isEmpty) return;
      final base = Uri.parse(_api.baseUrl);
      final prefix = base.path.replaceFirst(RegExp(r'/+$'), '');
      final uri = base.replace(
        scheme: base.scheme == 'https' ? 'wss' : 'ws',
        path: '$prefix/ws/breach-monitor',
        queryParameters: {'token': token},
      );
      try {
        await _breachMonitor.connect(uri, _onMonitorMessage);
      } catch (_) {
        // Saved alerts remain available from the notification inbox when live monitoring is unavailable.
      }
    } finally {
      _monitorConnecting = false;
    }
  }

  void _onMonitorMessage(Map<String, dynamic> message) {
    if (message['type'] != 'breach_alert' || !mounted) return;
    final data = (message['data'] as Map<String, dynamic>?) ?? {};
    final service =
        data['service']?.toString() ??
        data['email']?.toString() ??
        'An account';
    final breach = data['breach']?.toString() ?? 'a new exposure';
    if (!_locked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('New breach alert: $service appeared in $breach'),
        ),
      );
    }
    _loadUnreadCount();
  }

  Future<void> _loadBiometricSetting() async {
    final enabled = await _biometric.enabled;
    if (mounted) {
      setState(() {
        _biometricEnabled = enabled;
        _locked = enabled;
      });
      if (enabled) _unlock();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _appResumed = false;
      _breachMonitor.disconnect();
    }
    if (state == AppLifecycleState.resumed) {
      _appResumed = true;
      _connectBreachMonitor();
    }
    if (!_biometricEnabled || _authInProgress) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (mounted) setState(() => _locked = true);
    } else if (state == AppLifecycleState.resumed && _locked) {
      _unlock();
    }
  }

  Future<void> _configureBiometricLock() async {
    if (_biometricEnabled) {
      await _biometric.setEnabled(false);
      if (mounted) setState(() => _biometricEnabled = false);
      return;
    }
    setState(() => _authInProgress = true);
    try {
      final authenticated = await _biometric.authenticate();
      if (!mounted) return;
      if (authenticated) {
        await _biometric.setEnabled(true);
        if (!mounted) return;
        setState(() => _biometricEnabled = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric app lock enabled.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication was cancelled.')),
        );
      }
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.message ?? 'Biometric authentication is unavailable.',
            ),
          ),
        );
      }
    } on MissingPluginException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric lock is available on Android and iOS.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _authInProgress = false);
    }
  }

  Future<void> _unlock() async {
    if (_authInProgress) return;
    setState(() => _authInProgress = true);
    try {
      final authenticated = await _biometric.authenticate();
      if (mounted && authenticated) setState(() => _locked = false);
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Could not unlock PrivacyShield.'),
          ),
        );
      }
    } on MissingPluginException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric lock is unavailable on this device.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _authInProgress = false);
    }
  }

  Future<void> _checkConnection() async {
    final offline = await _api.isOffline;
    if (mounted) setState(() => _isOffline = offline);
  }

  Future<void> _loadUnreadCount() async {
    try {
      final data = await _api.get('/notifications/count');
      setState(
        () => _unreadCount = data['unread'] ?? data['unread_count'] ?? 0,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        leadingWidth: 36,
        leading: Center(
          child: Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(left: 16),
            color: AppColors.red,
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/notifications',
                  ).then((_) => _loadUnreadCount());
                },
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$_unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
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
              if (v == 'biometric') _configureBiometricLock();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'biometric',
                child: Row(
                  children: [
                    Icon(
                      _biometricEnabled ? Icons.fingerprint : Icons.fingerprint,
                      color: AppColors.blue,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _biometricEnabled
                          ? 'Disable biometric lock'
                          : 'Enable biometric lock',
                    ),
                  ],
                ),
              ),
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
      body: Stack(
        children: [
          Column(
            children: [
              if (_isOffline)
                Container(
                  width: double.infinity,
                  color: AppColors.orange.withAlpha(24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: const Text(
                    'Offline · showing data cached during this session where available',
                    style: TextStyle(color: AppColors.orange, fontSize: 12),
                  ),
                ),
              Expanded(
                child: IndexedStack(index: _currentIndex, children: _screens),
              ),
            ],
          ),
          if (_locked)
            Positioned.fill(
              child: ColoredBox(
                color: AppColors.surface,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.lock_outline,
                          size: 48,
                          color: AppColors.blue,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'PrivacyShield is locked',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Authenticate to protect your account and audit data.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _authInProgress ? null : _unlock,
                          icon: const Icon(Icons.fingerprint),
                          label: Text(_authInProgress ? 'Checking…' : 'Unlock'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
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
          BottomNavigationBarItem(
            icon: Icon(Icons.space_dashboard_outlined),
            label: 'Overview',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.phone_android),
            label: 'This phone',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.alternate_email),
            label: 'Accounts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.gpp_maybe_outlined),
            label: 'Breaches',
          ),
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
                    _moreNavItem(
                      Icons.password,
                      'Password Leak Check',
                      AppColors.red,
                      '/leak-check',
                    ),
                    _moreItem(Icons.hub, 'Risk graph', AppColors.red, 7),
                    _moreItem(Icons.smart_toy, 'PrivacyBot', AppColors.blue, 4),
                    _moreItem(Icons.link, 'Audit log', AppColors.purple, 5),
                    _moreItem(Icons.military_tech, 'Badges', AppColors.pink, 6),
                    const Divider(color: AppColors.border, height: 24),
                    _moreNavItem(
                      Icons.timeline,
                      'Timeline',
                      AppColors.cyan,
                      '/timeline',
                    ),
                    _moreNavItem(
                      Icons.group,
                      'Family Shield',
                      AppColors.green,
                      '/family',
                    ),
                    _moreNavItem(
                      Icons.search,
                      'Search',
                      AppColors.blue,
                      '/search',
                    ),
                    _moreNavItem(
                      Icons.assessment,
                      'Reports',
                      AppColors.purple,
                      '/reports',
                    ),
                    _moreNavItem(
                      Icons.fingerprint,
                      'DID Identity',
                      AppColors.cyan,
                      '/did',
                    ),
                    _moreNavItem(
                      Icons.how_to_vote,
                      'DAO Voting',
                      AppColors.orange,
                      '/dao',
                    ),
                    _moreNavItem(
                      Icons.dark_mode,
                      'Dark Web Monitor',
                      AppColors.red,
                      '/darkweb',
                    ),
                    _moreNavItem(
                      Icons.download,
                      'Smart Import',
                      AppColors.green,
                      '/smart-import',
                    ),
                    _moreNavItem(Icons.cloud_done_outlined, 'Connection status', AppColors.cyan, '/integration-status'),
                    _moreNavItem(
                      Icons.alarm,
                      'Reminders',
                      AppColors.orange,
                      '/reminders',
                    ),
                    _moreNavItem(
                      Icons.auto_awesome,
                      'AI Privacy Insights',
                      AppColors.purple,
                      '/ai-insights',
                    ),
                    _moreNavItem(
                      Icons.qr_code_scanner,
                      'QR Privacy Check',
                      AppColors.cyan,
                      '/qr-scanner',
                    ),
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
