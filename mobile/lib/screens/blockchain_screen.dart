import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../widgets/dossier.dart';
import '../services/api_service.dart';

class BlockchainScreen extends StatefulWidget {
  const BlockchainScreen({super.key});

  @override
  State<BlockchainScreen> createState() => _BlockchainScreenState();
}

class _BlockchainScreenState extends State<BlockchainScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tabCtrl;
  List<dynamic> _auditLog = [];
  List<dynamic> _chain = [];
  bool _loadingLog = true;
  bool _loadingChain = true;
  double _zkpThreshold = 70;
  Map<String, dynamic>? _zkpCert;
  bool _generatingZkp = false;
  String? _zkpError;
  Map<String, dynamic>? _zkpVerdict;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadAuditLog();
    _loadChain();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAuditLog() async {
    try {
      final data = await _api.getList('/blockchain/audit-log');
      setState(() {
        _auditLog = data;
        _loadingLog = false;
      });
    } catch (_) {
      setState(() => _loadingLog = false);
    }
  }

  Future<void> _loadChain() async {
    try {
      final data = await _api.get('/blockchain/chain');
      setState(() {
        _chain = (data['chain'] as List?) ?? [];
        _loadingChain = false;
      });
    } catch (_) {
      setState(() => _loadingChain = false);
    }
  }

  Future<void> _generateZkp() async {
    setState(() {
      _generatingZkp = true;
      _zkpError = null;
      _zkpVerdict = null;
    });
    try {
      final data = await _api.post('/blockchain/zkp/prove?threshold=${_zkpThreshold.toInt()}');
      setState(() => _zkpCert = data);
    } catch (e) {
      setState(() {
        _zkpCert = null;
        _zkpError = e is ApiException ? e.message : e.toString();
      });
    } finally {
      if (mounted) setState(() => _generatingZkp = false);
    }
  }

  /// Sends the proof to the public verifier, optionally after corrupting it to show it gets rejected.
  Future<void> _verifyZkp({bool tamper = false, bool claimHigher = false}) async {
    final package = jsonDecode(jsonEncode(_zkpCert!['package'])) as Map<String, dynamic>;
    if (tamper) {
      final bit = (package['proof']['bit_proofs'] as List).first as Map<String, dynamic>;
      final z = BigInt.parse((bit['z0'] as String).substring(2), radix: 16) + BigInt.one;
      bit['z0'] = '0x${z.toRadixString(16)}';
    }
    if (claimHigher) package['threshold'] = (package['threshold'] as int) + 10;
    setState(() => _verifying = true);
    try {
      final res = await _api.post('/blockchain/zkp/verify', body: package);
      setState(() => _zkpVerdict = {...res, 'mode': tamper ? 'tampered' : claimHigher ? 'inflated' : 'original'});
    } catch (e) {
      setState(() => _zkpError = e is ApiException ? e.message : e.toString());
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AppColors.surface,
          child: TabBar(
            controller: _tabCtrl,
            indicatorColor: AppColors.purple,
            labelColor: AppColors.purple,
            unselectedLabelColor: AppColors.textMuted,
            tabs: const [
              Tab(text: 'Audit Log'),
              Tab(text: 'Blocks'),
              Tab(text: 'ZKP'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [_buildAuditTab(), _buildChainTab(), _buildZkpTab()],
          ),
        ),
      ],
    );
  }

  Widget _buildAuditTab() {
    if (_loadingLog) return const Center(child: CircularProgressIndicator(color: AppColors.purple));
    if (_auditLog.isEmpty) return const Center(child: Text('No audit entries', style: TextStyle(color: AppColors.textMuted)));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _auditLog.length,
      itemBuilder: (_, i) {
        final entry = _auditLog[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.link, color: AppColors.purple, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(entry['action'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                ],
              ),
              if (entry['details'] != null) ...[
                const SizedBox(height: 4),
                Text(entry['details'], style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
              const SizedBox(height: 8),
              Text(
                'Hash: ${(entry['data_hash'] ?? '').toString().length > 20 ? '${entry['data_hash'].toString().substring(0, 20)}...' : entry['data_hash'] ?? 'N/A'}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontFamily: 'monospace'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChainTab() {
    if (_loadingChain) return const Center(child: CircularProgressIndicator(color: AppColors.purple));
    if (_chain.isEmpty) return const Center(child: Text('No blocks', style: TextStyle(color: AppColors.textMuted)));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _chain.length,
      itemBuilder: (_, i) {
        final block = _chain[_chain.length - 1 - i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.purple.withAlpha(60)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Block #${block['index'] ?? i}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.purple),
                  ),
                  Text(
                    'Nonce: ${block['nonce'] ?? 0}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _hashRow('Hash', block['hash']),
              _hashRow('Prev', block['previous_hash']),
              const SizedBox(height: 4),
              Text(
                '${block['timestamp'] ?? ''}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _hashRow(String label, dynamic hash) {
    final h = hash?.toString() ?? 'N/A';
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          SizedBox(width: 36, child: Text('$label:', style: const TextStyle(color: AppColors.textMuted, fontSize: 11))),
          Expanded(
            child: Text(
              h.length > 24 ? '${h.substring(0, 24)}...' : h,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZkpTab() {
    final cert = _zkpCert;
    final verdict = _zkpVerdict;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        Text('ZERO-KNOWLEDGE PROOF', style: AppText.eyebrow(color: AppColors.red)),
        const SizedBox(height: 4),
        Text('Prove it. Reveal nothing.', style: AppText.serif(size: 32)),
        const SizedBox(height: 6),
        const Text(
          'Show an employer, insurer or bank that your privacy score is above a bar without telling them the score. '
          'Your score is locked in a cryptographic commitment; the proof shows only that it clears the threshold.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5, height: 1.4),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Text('Claim: score is at least', style: TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${_zkpThreshold.toInt()}', style: AppText.serif(size: 34, color: AppColors.red)),
          ],
        ),
        Slider(
          value: _zkpThreshold,
          min: 0,
          max: 100,
          divisions: 20,
          activeColor: AppColors.ink,
          inactiveColor: AppColors.border,
          onChanged: (v) => setState(() => _zkpThreshold = v),
        ),
        ElevatedButton.icon(
          onPressed: _generatingZkp ? null : _generateZkp,
          icon: _generatingZkp
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background))
              : const Icon(Icons.enhanced_encryption_outlined),
          label: Text(_generatingZkp ? 'Computing proof (2048-bit)…' : 'Generate proof'),
        ),
        if (_zkpError != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(border: Border.all(color: AppColors.red, width: 1.5)),
            child: Text(_zkpError!, style: const TextStyle(color: AppColors.red)),
          ),
        ],
        if (cert != null) ...[
          const SizedBox(height: 22),
          Container(
            color: AppColors.ink,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PROOF PACKAGE', style: AppText.mono(size: 11, color: AppColors.red, weight: FontWeight.w700).copyWith(letterSpacing: 1.5)),
                const SizedBox(height: 8),
                Text(cert['claim'], style: AppText.serif(size: 24, color: AppColors.background)),
                const SizedBox(height: 12),
                _proofLine('scheme', cert['package']['proof']['scheme']),
                _proofLine('group', '${cert['package']['proof']['group']} (2048-bit)'),
                _proofLine('commitment', cert['package']['credential']['commitment']),
                _proofLine('bit proofs', '${(cert['package']['proof']['bit_proofs'] as List).length} OR-proofs (Fiat–Shamir)'),
                _proofLine('issuer', cert['package']['credential']['issuer']),
                _proofLine('size', '${(cert['proof_bytes'] / 1024).toStringAsFixed(1)} KB · built in ${cert['generated_ms']} ms'),
                const SizedBox(height: 10),
                Text('REVEALS  ${(cert['reveals'] as List).join(', ')}', style: AppText.mono(size: 10.5, color: const Color(0xFF8BC79B))),
                Text('HIDES    ${(cert['hides'] as List).join(', ')}', style: AppText.mono(size: 10.5, color: const Color(0xFFE5583F))),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text('Act as the verifier', style: AppText.serif(size: 22)),
          const Text(
            'The verifier endpoint is public: no login, no access to your data. Try it honestly, then try to cheat.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _verifying ? null : () => _verifyZkp(),
                icon: const Icon(Icons.verified_outlined, size: 18),
                label: const Text('Verify proof'),
              ),
              OutlinedButton.icon(
                onPressed: _verifying ? null : () => _verifyZkp(tamper: true),
                icon: const Icon(Icons.edit_off_outlined, size: 18),
                label: const Text('Tamper 1 byte'),
              ),
              OutlinedButton.icon(
                onPressed: _verifying ? null : () => _verifyZkp(claimHigher: true),
                icon: const Icon(Icons.trending_up, size: 18),
                label: const Text('Claim +10'),
              ),
            ],
          ),
          if (_verifying)
            const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: AppColors.red))),
          if (verdict != null && !_verifying) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: verdict['valid'] == true ? AppColors.green : AppColors.red, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: RubberStamp(
                      verdict['valid'] == true ? 'Verified' : 'Rejected',
                      color: verdict['valid'] == true ? AppColors.green : AppColors.red,
                      delay: Duration.zero,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    verdict['mode'] == 'tampered'
                        ? 'One byte of the proof was changed before sending.'
                        : verdict['mode'] == 'inflated'
                        ? 'The same proof was submitted claiming a threshold 10 points higher.'
                        : 'The untouched proof was submitted.',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                  ),
                  const SizedBox(height: 8),
                  for (final c in (verdict['checks'] as List))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(c['ok'] == true ? Icons.check : Icons.close, size: 16, color: c['ok'] == true ? AppColors.green : AppColors.red),
                          const SizedBox(width: 6),
                          Expanded(child: Text(c['check'], style: const TextStyle(fontSize: 13))),
                        ],
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text('${verdict['reason']} · ${verdict['verified_ms']} ms', style: AppText.mono(size: 10.5, color: AppColors.textMuted)),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _proofLine(String label, dynamic value) {
    final v = value?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 92, child: Text(label.toUpperCase(), style: AppText.mono(size: 10, color: const Color(0xFF8E897E)))),
          Expanded(
            child: Text(
              v.length > 40 ? '${v.substring(0, 22)}…${v.substring(v.length - 10)}' : v,
              style: AppText.mono(size: 10.5, color: AppColors.background),
            ),
          ),
        ],
      ),
    );
  }


}
