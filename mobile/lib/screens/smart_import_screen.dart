import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../services/device_audit.dart';
import '../services/password_csv_import.dart';
import '../widgets/dossier.dart';

/// Find the accounts you already have, three real ways:
/// the apps on this phone, a password-manager export, or an email you paste.
class SmartImportScreen extends StatefulWidget {
  const SmartImportScreen({super.key});

  @override
  State<SmartImportScreen> createState() => _SmartImportScreenState();
}

const _categoryIcon = {
  'email': Icons.email_outlined,
  'finance': Icons.account_balance,
  'social': Icons.people_outline,
  'cloud': Icons.cloud_outlined,
  'shopping': Icons.shopping_bag_outlined,
  'work': Icons.work_outline,
  'gaming': Icons.sports_esports_outlined,
  'entertainment': Icons.movie_outlined,
  'productivity': Icons.edit_note,
};

class _SmartImportScreenState extends State<SmartImportScreen> {
  final _api = ApiService();
  final _emailCtrl = TextEditingController();

  // Candidates waiting for the user to confirm, from the phone scan or the email scan.
  List<Map<String, dynamic>> _candidates = [];
  String _candidateSource = '';
  final Set<String> _selected = {};
  String? _busy; // which action is running
  String? _status;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  void _toast(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  String _err(Object e) => e is ApiException ? e.message : e.toString();

  void _setCandidates(List<Map<String, dynamic>> found, String source) {
    setState(() {
      _candidates = found;
      _candidateSource = source;
      _selected
        ..clear()
        ..addAll(found.where((c) => c['already_tracked'] != true).map((c) => c['service_name'] as String));
    });
  }

  Future<void> _scanPhone() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _toast('Scanning installed apps works on Android phones.');
      return;
    }
    setState(() => _busy = 'phone');
    try {
      final apps = await DeviceAuditService().scanApps();
      final res = await _api.post('/import/device-apps', body: {
        'apps': apps.where((a) => !a.system).map((a) => {'package': a.package, 'label': a.label}).toList(),
      });
      final found = (res['discovered'] as List).cast<Map<String, dynamic>>();
      _setCandidates(found, 'device_apps');
      setState(() => _status = 'Checked ${res['apps_scanned']} apps · found ${found.length} known services, '
          '${res['new_accounts']} not in PrivacyShield yet.');
    } catch (e) {
      _toast('Phone scan failed: ${_err(e)}');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _scanEmail() async {
    final text = _emailCtrl.text.trim();
    if (text.isEmpty) {
      _toast('Paste the text of an email first (a signup, receipt or security alert works best).');
      return;
    }
    setState(() => _busy = 'email');
    try {
      final res = await _api.post('/import/scan-email', body: {'email_content': text});
      final found = (res['discovered'] as List).cast<Map<String, dynamic>>();
      _setCandidates(found, 'email_paste');
      setState(() => _status = 'Found ${found.length} sites in that email · ${res['new_accounts']} new.');
    } catch (e) {
      _toast('Email scan failed: ${_err(e)}');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _addSelected() async {
    if (_selected.isEmpty) return;
    setState(() => _busy = 'add');
    try {
      final res = await _api.post('/import/bulk-add', body: {
        'services': _selected.toList(),
        'added_via': _candidateSource,
        'import_confidence': _candidateSource == 'device_apps' ? 0.9 : 0.7,
        'evidence_source': _candidateSource == 'device_apps' ? 'installed_app_on_this_phone' : 'domain_in_pasted_email',
      });
      final added = (res['added'] as List).length;
      setState(() {
        _status = 'Added $added account${added == 1 ? '' : 's'}. Open Overview to see your updated risk.';
        _candidates = [];
        _selected.clear();
      });
    } catch (e) {
      _toast('Import failed: ${_err(e)}');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _importCsvText(String contents) async {
    final parsed = parsePasswordManagerCsv(contents);
    if (parsed.isEmpty) {
      _toast("That doesn't look like a password-manager export (no name and password columns).");
      return;
    }
    setState(() => _busy = 'csv');
    try {
      // Built from the reduced record type: password cells are never serialised.
      final res = await _api.post('/import/password-manager-csv', body: {
        'services': parsed.map((row) => row.toApiJson()).toList(),
      });
      final added = (res['added'] as List).length;
      final reuse = parsed.where((p) => p.passwordGroup != null).length;
      setState(() => _status = 'Read ${parsed.length} logins on this phone · $reuse share a password · '
          'added $added new account${added == 1 ? '' : 's'}. No password left the device.');
    } catch (e) {
      _toast('CSV import failed: ${_err(e)}');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _pickCsv() async {
    try {
      final file = await FilePicker.pickFile(type: FileType.any);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      await _importCsvText(utf8.decode(bytes, allowMalformed: true));
    } catch (e) {
      _toast('Could not open that file: ${_err(e)}');
    }
  }

  Future<void> _pasteCsv() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.trim().isEmpty) {
      _toast('The clipboard is empty. Copy the CSV export first.');
      return;
    }
    await _importCsvText(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Import')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text('Find the accounts you already have.', style: AppText.serif(size: 34)),
          const SizedBox(height: 6),
          const Text(
            'Three ways in. Nothing is added until you confirm it, and passwords never leave this phone.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          if (_status != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(border: Border.all(color: AppColors.green, width: 1.5)),
              child: Text(_status!, style: const TextStyle(color: AppColors.green)),
            ),
          ],
          const CaseHeading(code: 'Method 01', title: 'Scan this phone'),
          const Text(
            'Reads the list of apps installed here and matches them against ~100 known services: banks, UPI, '
            'social, shopping, cloud. App data is not read.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
          ),
          const SizedBox(height: 10),
          _actionButton('phone', Icons.phone_android, 'Scan installed apps', _scanPhone, primary: true),
          if (_candidates.isNotEmpty) _candidateList(),
          const CaseHeading(code: 'Method 02', title: 'Password manager export'),
          const Text(
            'Export from Google Password Manager (passwords.google.com → Settings → Export), Chrome, Bitwarden, '
            '1Password or LastPass. The file is read on this phone: reused passwords are detected here, and only '
            'the site, login name and a "reuse group" label are sent.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _actionButton('csv', Icons.upload_file, 'Choose CSV file', _pickCsv)),
              const SizedBox(width: 8),
              Expanded(child: _actionButton('csv', Icons.content_paste, 'Paste CSV', _pasteCsv)),
            ],
          ),
          const CaseHeading(code: 'Method 03', title: 'Paste an email'),
          const Text(
            'Paste a signup confirmation, receipt or security alert. Every website it mentions is found and checked '
            'against the Have I Been Pwned breach catalog.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _emailCtrl,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Welcome to Dropbox! Confirm your account at https://www.dropbox.com/…',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          _actionButton('email', Icons.manage_search, 'Find accounts in this email', _scanEmail),
        ],
      ),
    );
  }

  Widget _actionButton(String key, IconData icon, String label, VoidCallback onTap, {bool primary = false}) {
    final running = _busy == key;
    final child = running
        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
        : Icon(icon);
    return primary
        ? ElevatedButton.icon(onPressed: _busy != null ? null : onTap, icon: child, label: Text(label))
        : OutlinedButton.icon(onPressed: _busy != null ? null : onTap, icon: child, label: Text(label));
  }

  Widget _candidateList() {
    final fresh = _candidates.where((c) => c['already_tracked'] != true).length;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(border: Border.all(color: AppColors.ink, width: 1.2), color: AppColors.surface),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: AppColors.ink,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Text(
                  _candidateSource == 'device_apps' ? 'FOUND ON THIS PHONE' : 'FOUND IN EMAIL',
                  style: AppText.mono(size: 11, color: AppColors.background, weight: FontWeight.w700).copyWith(letterSpacing: 1.4),
                ),
                const Spacer(),
                Text('$fresh NEW · ${_candidates.length - fresh} TRACKED', style: AppText.mono(size: 10.5, color: const Color(0xFF8E897E))),
              ],
            ),
          ),
          for (final c in _candidates) _candidateRow(c),
          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton.icon(
              onPressed: _busy != null || _selected.isEmpty ? null : _addSelected,
              icon: _busy == 'add'
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add),
              label: Text('Add ${_selected.length} account${_selected.length == 1 ? '' : 's'}'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _candidateRow(Map<String, dynamic> c) {
    final name = c['service_name'] as String;
    final tracked = c['already_tracked'] == true;
    final breached = c['breached'] == true;
    return CheckboxListTile(
      value: tracked || _selected.contains(name),
      onChanged: tracked
          ? null
          : (v) => setState(() => v == true ? _selected.add(name) : _selected.remove(name)),
      activeColor: AppColors.ink,
      secondary: Icon(_categoryIcon[c['category']] ?? Icons.language, color: breached ? AppColors.red : AppColors.textSecondary),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        [
          c['category'] ?? 'other',
          if (tracked) 'already tracked',
          if (breached) 'breached: ${c['breach_name']}${c['breach_date'] != null ? ' (${c['breach_date']})' : ''}',
        ].join(' · '),
        style: TextStyle(fontSize: 12, color: breached ? AppColors.red : AppColors.textMuted),
      ),
    );
  }
}
