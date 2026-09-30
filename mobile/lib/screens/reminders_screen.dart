import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/api_service.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final _api = ApiService();
  List<dynamic> _reminders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    setState(() => _loading = true);
    try {
      final data = await _api.get('/reminders/');
      setState(() {
        _reminders = (data['reminders'] as List?) ?? (data['data'] as List?) ?? [];
        _loading = false;
      });
    } catch (_) {
      // Try getList as fallback
      try {
        final data = await _api.getList('/reminders/');
        setState(() {
          _reminders = data;
          _loading = false;
        });
      } catch (_) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _completeReminder(int id) async {
    try {
      await _api.post('/reminders/$id/complete');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder completed')),
        );
      }
      _loadReminders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _toggleReminder(int id) async {
    try {
      await _api.patch('/reminders/$id/toggle');
      _loadReminders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  bool _isDue(dynamic reminder) {
    final nextTrigger = reminder['next_trigger'] ?? reminder['next_trigger_date'];
    if (nextTrigger == null) return false;
    try {
      final date = DateTime.parse(nextTrigger.toString());
      return date.isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.blue))
          : _reminders.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_off, size: 48, color: AppColors.textMuted),
                      SizedBox(height: 12),
                      Text('No reminders', style: TextStyle(color: AppColors.textMuted)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadReminders,
                  color: AppColors.blue,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _reminders.length,
                    itemBuilder: (_, i) => _buildReminderCard(_reminders[i]),
                  ),
                ),
    );
  }

  Widget _buildReminderCard(dynamic reminder) {
    final isDue = _isDue(reminder);
    final isActive = reminder['is_active'] ?? reminder['active'] ?? true;
    final id = reminder['id'] as int;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDue ? AppColors.orange : AppColors.border,
          width: isDue ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isDue ? Icons.alarm_on : Icons.alarm,
                color: isDue ? AppColors.orange : AppColors.blue,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  reminder['title'] ?? 'Reminder',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: isActive ? AppColors.textPrimary : AppColors.textMuted,
                  ),
                ),
              ),
              if (isDue)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.orange.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'DUE',
                    style: TextStyle(color: AppColors.orange, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          if (reminder['description'] != null) ...[
            const SizedBox(height: 8),
            Text(
              reminder['description'],
              style: TextStyle(
                color: isActive ? AppColors.textSecondary : AppColors.textMuted,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              if (reminder['frequency'] != null) ...[
                Icon(Icons.repeat, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  reminder['frequency'],
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                const SizedBox(width: 16),
              ],
              if (reminder['next_trigger'] != null || reminder['next_trigger_date'] != null) ...[
                Icon(Icons.schedule, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  (reminder['next_trigger'] ?? reminder['next_trigger_date']).toString(),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _completeReminder(id),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Complete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.green,
                    side: const BorderSide(color: AppColors.green),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _toggleReminder(id),
                  icon: Icon(isActive ? Icons.pause : Icons.play_arrow, size: 16),
                  label: Text(isActive ? 'Pause' : 'Resume'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isActive ? AppColors.orange : AppColors.blue,
                    side: BorderSide(color: isActive ? AppColors.orange : AppColors.blue),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
