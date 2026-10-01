import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/api_service.dart';

class ServerSettingsDialog extends StatefulWidget {
  final VoidCallback? onSaved;

  const ServerSettingsDialog({super.key, this.onSaved});

  static Future<void> show(BuildContext context, {VoidCallback? onSaved}) {
    return showDialog(
      context: context,
      builder: (_) => ServerSettingsDialog(onSaved: onSaved),
    );
  }

  @override
  State<ServerSettingsDialog> createState() => _ServerSettingsDialogState();
}

class _ServerSettingsDialogState extends State<ServerSettingsDialog> {
  final _urlCtrl = TextEditingController();
  final _api = ApiService();
  bool _testing = false;
  String? _testResult;
  bool? _testSuccess;

  @override
  void initState() {
    super.initState();
    _urlCtrl.text = _api.baseUrl;
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
      _testSuccess = null;
    });

    final res = await _api.testConnection(_urlCtrl.text);

    if (mounted) {
      setState(() {
        _testing = false;
        _testSuccess = res['success'] as bool;
        _testResult = res['message'] as String;
      });
    }
  }

  Future<void> _save() async {
    await _api.setCustomBaseUrl(_urlCtrl.text.trim());
    if (widget.onSaved != null) {
      widget.onSaved!();
    }
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Server URL set to: ${_api.baseUrl}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _reset() async {
    await _api.setCustomBaseUrl(null);
    setState(() {
      _urlCtrl.text = _api.baseUrl;
      _testResult = null;
      _testSuccess = null;
    });
    if (widget.onSaved != null) {
      widget.onSaved!();
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Server URL reset to: ${_api.baseUrl}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _applyPreset(String presetUrl) {
    setState(() {
      _urlCtrl.text = presetUrl;
      _testResult = null;
      _testSuccess = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.ink.withAlpha(15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.settings_ethernet, color: AppColors.ink, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Backend Server URL',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'If you are testing on a real Android phone, 10.0.2.2 will not connect. '
              'Select a preset below or enter your computer\'s Wi-Fi IP address.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlCtrl,
              decoration: const InputDecoration(
                labelText: 'Base API URL',
                hintText: 'http://192.168.x.x:8000/api',
                prefixIcon: Icon(Icons.link, color: AppColors.textMuted),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            const Text(
              'Quick Presets:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.wifi, size: 14, color: AppColors.ink),
                  label: const Text('Wi-Fi PC (10.183.82.30)', style: TextStyle(fontSize: 11)),
                  onPressed: () => _applyPreset('http://10.183.82.30:8000/api'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.usb, size: 14, color: AppColors.ink),
                  label: const Text('USB adb reverse (localhost)', style: TextStyle(fontSize: 11)),
                  onPressed: () => _applyPreset('http://localhost:8000/api'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.android, size: 14, color: AppColors.ink),
                  label: const Text('Emulator (10.0.2.2)', style: TextStyle(fontSize: 11)),
                  onPressed: () => _applyPreset('http://10.0.2.2:8000/api'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _testing ? null : _testConnection,
              icon: _testing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.network_ping, size: 16),
              label: Text(_testing ? 'Testing connection...' : 'Test Connection'),
            ),
            if (_testResult != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _testSuccess == true
                      ? AppColors.green.withAlpha(20)
                      : AppColors.red.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _testSuccess == true
                        ? AppColors.green.withAlpha(80)
                        : AppColors.red.withAlpha(80),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _testSuccess == true ? Icons.check_circle_outline : Icons.error_outline,
                      color: _testSuccess == true ? AppColors.green : AppColors.red,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _testResult!,
                        style: TextStyle(
                          color: _testSuccess == true ? AppColors.green : AppColors.red,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _reset,
          child: const Text('Reset', style: TextStyle(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save & Apply'),
        ),
      ],
    );
  }
}
