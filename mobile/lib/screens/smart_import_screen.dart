import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/api_service.dart';

class SmartImportScreen extends StatefulWidget {
  const SmartImportScreen({super.key});

  @override
  State<SmartImportScreen> createState() => _SmartImportScreenState();
}

class _SmartImportScreenState extends State<SmartImportScreen> {
  final _api = ApiService();
  final _emailCtrl = TextEditingController();
  final _emailContentCtrl = TextEditingController();
  List<dynamic> _suggestions = [];
  final Set<String> _selectedServices = {};
  bool _loading = true;
  bool _importing = false;
  bool _scanningEmail = false;
  Map<String, dynamic>? _importResult;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _emailContentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    setState(() => _loading = true);
    try {
      final data = await _api.get('/import/suggestions');
      setState(() {
        _suggestions = (data['suggestions'] as List?) ?? [];
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _importSelected() async {
    if (_selectedServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one service')),
      );
      return;
    }
    setState(() => _importing = true);
    try {
      final data = await _api.post('/import/bulk-add', body: {
        'services': _selectedServices.toList(),
        'email': _emailCtrl.text.trim(),
      });
      setState(() {
        _importResult = data;
        _importing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added: ${data['added'] ?? 0}, Skipped: ${data['skipped'] ?? 0}',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _importing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  Future<void> _scanEmail() async {
    if (_emailContentCtrl.text.trim().isEmpty) return;
    setState(() => _scanningEmail = true);
    try {
      final data = await _api.post('/import/scan-email', body: {
        'content': _emailContentCtrl.text.trim(),
      });
      final found = (data['services'] as List?) ?? [];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Found ${found.length} services in email')),
        );
      }
      if (found.isNotEmpty) {
        setState(() {
          for (final s in found) {
            _selectedServices.add(s['name'] ?? s.toString());
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e')),
        );
      }
    }
    setState(() => _scanningEmail = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Import')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.blue))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Suggested Services',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Common services not yet tracked in your account',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                if (_suggestions.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Center(
                      child: Text('No suggestions available', style: TextStyle(color: AppColors.textMuted)),
                    ),
                  )
                else
                  ..._suggestions.map((s) {
                    final name = s['name'] ?? s['service_name'] ?? s.toString();
                    final isSelected = _selectedServices.contains(name);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.blue : AppColors.border,
                        ),
                      ),
                      child: CheckboxListTile(
                        value: isSelected,
                        activeColor: AppColors.blue,
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: s['category'] != null
                            ? Text(s['category'], style: const TextStyle(color: AppColors.textMuted, fontSize: 12))
                            : null,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selectedServices.add(name);
                            } else {
                              _selectedServices.remove(name);
                            }
                          });
                        },
                      ),
                    );
                  }),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Your Email',
                    prefixIcon: Icon(Icons.email, color: AppColors.textMuted),
                    hintText: 'email@example.com',
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _importing ? null : _importSelected,
                    icon: _importing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.download),
                    label: Text(_importing
                        ? 'Importing...'
                        : 'Import Selected (${_selectedServices.length})'),
                  ),
                ),
                if (_importResult != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.green.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.green.withAlpha(60)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            Text(
                              '${_importResult!['added'] ?? 0}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.green,
                              ),
                            ),
                            const Text('Added', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              '${_importResult!['skipped'] ?? 0}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.orange,
                              ),
                            ),
                            const Text('Skipped', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                const Text(
                  'Scan Email Content',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Paste email content to detect services',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailContentCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email Content',
                    alignLabelWithHint: true,
                    hintText: 'Paste email text here...',
                  ),
                  maxLines: 5,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _scanningEmail ? null : _scanEmail,
                    icon: _scanningEmail
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.blue),
                          )
                        : const Icon(Icons.document_scanner),
                    label: Text(_scanningEmail ? 'Scanning...' : 'Scan Email'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.blue,
                      side: const BorderSide(color: AppColors.blue),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
