import 'package:flutter/material.dart';
import '../config/theme.dart';
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
    setState(() => _generatingZkp = true);
    try {
      final data = await _api.post('/blockchain/zkp-certificate', body: {
        'threshold': _zkpThreshold.toInt(),
      });
      setState(() {
        _zkpCert = data;
        _generatingZkp = false;
      });
    } catch (_) {
      setState(() => _generatingZkp = false);
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.purple.withAlpha(30),
            ),
            child: const Icon(Icons.verified, size: 56, color: AppColors.purple),
          ),
          const SizedBox(height: 20),
          const Text('Zero-Knowledge Proof', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Prove your privacy score exceeds a threshold without revealing your accounts',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Threshold', style: TextStyle(fontWeight: FontWeight.w500)),
              Text('${_zkpThreshold.toInt()}', style: const TextStyle(color: AppColors.purple, fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: _zkpThreshold,
            min: 10,
            max: 100,
            divisions: 9,
            activeColor: AppColors.purple,
            inactiveColor: AppColors.surfaceLight,
            onChanged: (v) => setState(() => _zkpThreshold = v),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _generatingZkp ? null : _generateZkp,
            icon: _generatingZkp
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.key),
            label: Text(_generatingZkp ? 'Generating...' : 'Generate Proof'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.purple,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            ),
          ),
          if (_zkpCert != null) ...[
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.purple.withAlpha(80)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _zkpCert!['verified'] == true ? Icons.check_circle : Icons.cancel,
                        color: _zkpCert!['verified'] == true ? AppColors.green : AppColors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _zkpCert!['verified'] == true ? 'Proof Valid' : 'Score Below Threshold',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _zkpCert!['verified'] == true ? AppColors.green : AppColors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _zkpField('Commitment', _zkpCert!['commitment']),
                  _zkpField('Challenge', _zkpCert!['challenge']),
                  _zkpField('Response', _zkpCert!['response']),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _zkpField(String label, dynamic value) {
    final v = value?.toString() ?? 'N/A';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(height: 2),
          Text(
            v.length > 32 ? '${v.substring(0, 32)}...' : v,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
