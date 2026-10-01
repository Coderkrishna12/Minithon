import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../services/password_csv_import.dart';

class SmartImportScreen extends StatefulWidget {
  const SmartImportScreen({super.key});

  @override
  State<SmartImportScreen> createState() => _SmartImportScreenState();
}

class _SmartImportScreenState extends State<SmartImportScreen> {
  final _api = ApiService();
  final _csvController = TextEditingController();
  final Set<String> _selectedServices = {};
  bool _loading = true;
  bool _importing = false;
  bool _scanningEmail = false;
  bool _importingCsv = false;
  Map<String, dynamic>? _importResult;

  @override
  void initState() {
    super.initState();
    _loading = false;
  }

  @override
  void dispose() {
    _csvController.dispose();
    super.dispose();
  }

  Future<void> _importPasswordCsv() async {
    final parsed = parsePasswordManagerCsv(_csvController.text);
    if (parsed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not find service and password columns in this CSV.')));
      return;
    }
    setState(() => _importingCsv = true);
    try {
      // The request is intentionally built from the reduced record type. Password cells are never serialized.
      final result = await _api.post('/import/password-manager-csv', body: {
        'services': parsed.map((row) => row.toApiJson()).toList(),
      });
      _csvController.clear(); // Drop the raw export from the screen immediately after local analysis.
      if (mounted) {
        setState(() { _importResult = result; _importingCsv = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added ${(result['added'] as List?)?.length ?? 0} accounts. Passwords stayed on this device.')));
      }
    } catch (e) {
      _csvController.clear();
      if (mounted) {
        setState(() => _importingCsv = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CSV import failed: $e')));
      }
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
      final fixture = _importResult?['mode'] == 'fixture';
      final data = await _api.post(
        '/import/bulk-add',
        body: {
          'services': _selectedServices.toList(),
          'added_via': fixture ? 'fixture_mailbox' : 'manual_review',
          'import_confidence': fixture ? 0.9 : null,
          'evidence_source': fixture ? 'DEMO DATA · signup/security signal reviewed by user' : 'user_confirmed',
        },
      );
      setState(() {
        _importResult = data;
        _importing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added: ${(data['added'] as List?)?.length ?? 0}, Skipped: ${(data['skipped'] as List?)?.length ?? 0}',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _importing = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    }
  }

  Future<void> _scanEmail() async {
    setState(() => _scanningEmail = true);
    try {
      final data = await _api.post('/import/fixture-mailbox/scan');
      final found = (data['discovered'] as List?) ?? [];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reviewed ${found.length} demo mailbox signals')),
        );
      }
      if (found.isNotEmpty) {
        setState(() {
          for (final s in found) {
            if (s['importable'] == true) {
              _selectedServices.add(s['service_name'] ?? s.toString());
            }
          }
          _importResult = data;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Scan failed: $e')));
      }
    }
    setState(() => _scanningEmail = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Import')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.blue),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Account discovery',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Only confirmed signup and security signals are candidates. Breach catalogs do not prove you have an account.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                if (_importResult?['mode'] == 'fixture')
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.orange.withAlpha(20), borderRadius: BorderRadius.circular(12)),
                    child: const Text('DEMO DATA · Fixture mailbox only. No real mailbox was connected.', style: TextStyle(color: AppColors.orange, fontSize: 12)),
                  ),
                if ((_importResult?['discovered'] as List?) == null)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Center(
                      child: Text(
                        'Run the fixture scan below to review discovered account signals.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  )
                else
                  ...((_importResult?['discovered'] as List?) ?? const []).map((s) {
                    final name = s['name'] ?? s['service_name'] ?? s.toString();
                    final isSelected = _selectedServices.contains(name);
                    final importable = s['importable'] != false && s['already_tracked'] != true;
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
                        enabled: importable,
                        activeColor: AppColors.blue,
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: s['reason'] != null
                            ? Text('${s['reason']} · ${((s['confidence'] ?? 0) * 100).round()}% confidence', style: const TextStyle(color: AppColors.textMuted, fontSize: 12))
                            : s['category'] != null
                            ? Text(
                                s['category'],
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              )
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _importing ? null : _importSelected,
                    icon: _importing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download),
                    label: Text(
                      _importing
                          ? 'Importing...'
                          : 'Import Selected (${_selectedServices.length})',
                    ),
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
                              '${(_importResult!['added'] as List?)?.length ?? 0}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.green,
                              ),
                            ),
                            const Text(
                              'Added',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              '${(_importResult!['skipped'] as List?)?.length ?? 0}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.orange,
                              ),
                            ),
                            const Text(
                              'Skipped',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                const Text('Password-manager CSV', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Paste an exported CSV. Reuse is detected on this device; only service names and reuse-group labels are sent.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 12),
                TextField(controller: _csvController, maxLines: 6, autocorrect: false, enableSuggestions: false,
                  decoration: const InputDecoration(labelText: 'CSV export', hintText: 'name,url,username,password\\nExample,example.com,user,password…', alignLabelWithHint: true)),
                const SizedBox(height: 10),
                OutlinedButton.icon(onPressed: _importingCsv ? null : _importPasswordCsv,
                  icon: _importingCsv ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.lock_outline),
                  label: Text(_importingCsv ? 'Checking locally…' : 'Analyze and import CSV')),
                const SizedBox(height: 24),
                const Text(
                  'Try the fixture mailbox',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'A reproducible demo of signup and security signals. Your inbox is never uploaded.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _scanningEmail ? null : _scanEmail,
                    icon: _scanningEmail
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.blue,
                            ),
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
