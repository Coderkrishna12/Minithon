import 'package:flutter/material.dart';
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
      default: return AppColors.blue;
    }
  }

  IconData _severityIcon(String severity) {
    switch (severity) {
      case 'critical': return Icons.error;
      case 'warning': return Icons.warning_amber;
      default: return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_notifications.any((n) => n['is_read'] != true))
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark All Read', style: TextStyle(color: AppColors.blue, fontSize: 13)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.blue))
          : _notifications.isEmpty
              ? const Center(child: Text('No notifications', style: TextStyle(color: AppColors.textMuted)))
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  color: AppColors.blue,
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
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isRead ? AppColors.border : _severityColor(severity).withAlpha(80),
                            ),
                          ),
                          child: ListTile(
                            leading: Icon(_severityIcon(severity), color: _severityColor(severity)),
                            title: Text(n['title'] ?? '', style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.w600, fontSize: 14)),
                            subtitle: Text(
                              n['message'] ?? '',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: !isRead
                                ? GestureDetector(
                                    onTap: () => _markRead(n['id']),
                                    child: Container(
                                      width: 8,
                                      height: 8,
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
    );
  }
}
