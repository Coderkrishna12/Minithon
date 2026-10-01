import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../services/api_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _api = ApiService();
  List<dynamic> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final data = await _api.getList('/notifications/');
      setState(() {
        _notifications = data;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _markRead(int id) async {
    try {
      await _api.patch('/notifications/$id/read');
      _loadNotifications();
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    try {
      await _api.patch('/notifications/read-all');
      _loadNotifications();
    } catch (_) {}
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'critical': return AppColors.red;
      case 'warning': return AppColors.orange;
      default: return AppColors.titanium;
    }
  }

  IconData _severityIcon(String severity) {
    switch (severity) {
      case 'critical': return Icons.priority_high;
      case 'warning': return Icons.warning_amber_outlined;
      default: return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'SECURITY TELEMETRY LOGS',
          style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.2),
        ),
        actions: [
          if (_notifications.any((n) => n['is_read'] != true))
            TextButton(
              onPressed: _markAllRead,
              child: const Text('MARK ALL READ'),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.textPrimary))
              : _notifications.isEmpty
                  ? Center(
                      child: Text(
                        'NO ACTIVE ALERTS',
                        style: GoogleFonts.spaceGrotesk(color: AppColors.textMuted, fontSize: 12, letterSpacing: 1.0),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadNotifications,
                      color: AppColors.textPrimary,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _notifications.length,
                        itemBuilder: (_, i) {
                          final n = _notifications[i];
                          final severity = n['severity'] ?? 'info';
                          final isRead = n['is_read'] == true;
                          return Opacity(
                            opacity: isRead ? 0.6 : 1.0,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isRead ? AppColors.border : _severityColor(severity).withAlpha(120),
                                  width: 1.0,
                                ),
                              ),
                              child: ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                leading: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceLight,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppColors.border, width: 1.0),
                                  ),
                                  child: Icon(_severityIcon(severity), color: _severityColor(severity), size: 14),
                                ),
                                title: Text(
                                  (n['title'] ?? '').toString().toUpperCase(),
                                  style: GoogleFonts.spaceGrotesk(
                                    fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                                    fontSize: 13,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                subtitle: Text(
                                  n['message'] ?? '',
                                  style: GoogleFonts.spaceGrotesk(color: AppColors.textSecondary, fontSize: 11),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: !isRead
                                    ? GestureDetector(
                                        onTap: () => _markRead(n['id']),
                                        child: Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: _severityColor(severity),
                                          ),
                                        ),
                                      )
                                    : null,
                                onTap: () {
                                  if (!isRead) _markRead(n['id']);
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ),
    );
  }
}
