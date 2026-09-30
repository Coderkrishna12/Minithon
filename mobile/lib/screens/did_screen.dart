import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/api_service.dart';

class DIDScreen extends StatefulWidget {
  const DIDScreen({super.key});

  @override
  State<DIDScreen> createState() => _DIDScreenState();
}

class _DIDScreenState extends State<DIDScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _didData;
  bool _loading = true;
  bool _creating = false;
  bool _verifying = false;
  bool _issuing = false;

  @override
  void initState() {
    super.initState();
    _loadDID();
  }

  Future<void> _loadDID() async {
    setState(() => _loading = true);
    try {
      final data = await _api.get('/did/');
      setState(() {
        _didData = data;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _didData = null;
        _loading = false;
      });
    }
  }

  Future<void> _createDID() async {
    setState(() => _creating = true);
    try {
      final data = await _api.post('/did/create');
      setState(() {
        _didData = data;
        _creating = false;
      });
    } catch (e) {
      setState(() => _creating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create DID: $e')),
        );
      }
    }
  }

  Future<void> _verifyDID() async {
    final didString = _didData?['did'] ?? _didData?['did_string'];
    if (didString == null) return;
    setState(() => _verifying = true);
    try {
      final data = await _api.post('/did/verify?did_string=$didString');
      if (mounted) {
        final verified = data['verified'] ?? data['valid'] ?? false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(verified ? 'DID verified successfully' : 'DID verification failed'),
            backgroundColor: verified ? AppColors.green : AppColors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification error: $e')),
        );
      }
    }
    setState(() => _verifying = false);
  }

  Future<void> _issueCredential() async {
    setState(() => _issuing = true);
    try {
      await _api.post('/did/issue-credential');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Credential issued successfully')),
        );
      }
      _loadDID();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to issue credential: $e')),
        );
      }
    }
    setState(() => _issuing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DID Identity')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.blue))
          : _didData == null || _didData!.isEmpty || _didData!['did'] == null && _didData!['did_string'] == null
              ? _buildCreateView()
              : _buildIdentityView(),
    );
  }

  Widget _buildCreateView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.cyan.withAlpha(30),
              ),
              child: const Icon(Icons.fingerprint, size: 64, color: AppColors.cyan),
            ),
            const SizedBox(height: 24),
            const Text(
              'Decentralized Identity',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create your decentralized identifier to take control of your digital identity',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _creating ? null : _createDID,
              icon: _creating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.add_circle_outline),
              label: Text(_creating ? 'Creating...' : 'Create DID'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cyan,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentityView() {
    final did = _didData!['did'] ?? _didData!['did_string'] ?? '';
    final publicKey = _didData!['public_key'] ?? '';
    final verificationMethod = _didData!['verification_method'] ?? '';
    final credentials = (_didData!['credentials'] as List?) ?? [];

    return RefreshIndicator(
      onRefresh: _loadDID,
      color: AppColors.blue,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(19),
              gradient: const LinearGradient(
                colors: [AppColors.cyan, AppColors.blue, AppColors.purple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.fingerprint, color: AppColors.cyan, size: 28),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Digital Identity Card',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.green.withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Active',
                          style: TextStyle(color: AppColors.green, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('DID', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(
                    did.toString(),
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.textSecondary),
                  ),
                  if (publicKey.toString().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Public Key', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(
                      publicKey.toString().length > 64
                          ? '${publicKey.toString().substring(0, 64)}...'
                          : publicKey.toString(),
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textSecondary),
                    ),
                  ],
                  if (verificationMethod.toString().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Verification Method', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(
                      verificationMethod.toString(),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _verifying ? null : _verifyDID,
                  icon: _verifying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.verified, size: 18),
                  label: Text(_verifying ? 'Verifying...' : 'Verify DID'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _issuing ? null : _issueCredential,
                  icon: _issuing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.badge, size: 18),
                  label: Text(_issuing ? 'Issuing...' : 'Issue Credential'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.purple,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          if (credentials.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text('Credentials', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...credentials.map((cred) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user, color: AppColors.cyan, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cred['type'] ?? cred['name'] ?? 'Credential',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            if (cred['issued_at'] != null || cred['issuer'] != null)
                              Text(
                                cred['issuer'] ?? cred['issued_at'] ?? '',
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.green.withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          cred['status'] ?? 'valid',
                          style: const TextStyle(color: AppColors.green, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}
