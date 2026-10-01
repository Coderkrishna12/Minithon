import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../services/api_service.dart';

class AiInsightsScreen extends StatefulWidget {
  const AiInsightsScreen({super.key});

  @override
  State<AiInsightsScreen> createState() => _AiInsightsScreenState();
}

class _AiInsightsScreenState extends State<AiInsightsScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  final _policyUrl = TextEditingController();
  late final TabController _tabs;
  List<dynamic> _permissions = [];
  Map<String, dynamic>? _twin;
  Map<String, dynamic>? _policy;
  bool _loadingPermissions = true;
  bool _loadingTwin = false;
  bool _analyzingPolicy = false;
  String? _permissionError;
  String? _twinError;
  String? _policyError;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadPermissions();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _policyUrl.dispose();
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    setState(() {
      _loadingPermissions = true;
      _permissionError = null;
    });
    try {
      final result = await _api.get('/ai/permission-advisor');
      if (!mounted) return;
      setState(() {
        _permissions = (result['recommendations'] as List?) ?? [];
        _loadingPermissions = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingPermissions = false;
        _permissionError = e.toString();
      });
    }
  }

  Future<void> _runTwin() async {
    setState(() {
      _loadingTwin = true;
      _twinError = null;
    });
    try {
      final result = await _api.post('/ai/digital-twin');
      if (!mounted) return;
      setState(() {
        _twin = result;
        _loadingTwin = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingTwin = false;
        _twinError = e.toString();
      });
    }
  }

  Future<void> _analyzePolicy() async {
    final raw = _policyUrl.text.trim();
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        !{'https', 'http'}.contains(uri.scheme) ||
        uri.host.isEmpty) {
      setState(
        () => _policyError =
            'Enter a complete policy URL beginning with https://',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _analyzingPolicy = true;
      _policyError = null;
      _policy = null;
    });
    try {
      final result = await _api.post(
        '/ai/analyze-policy',
        body: {'url': uri.toString()},
      );
      if (!mounted) return;
      setState(() {
        _policy = result;
        _analyzingPolicy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _analyzingPolicy = false;
        _policyError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Privacy Insights'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Permissions'),
            Tab(text: 'Risk simulation'),
            Tab(text: 'Policy watch'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_permissionsTab(), _twinTab(), _policyTab()],
      ),
    );
  }

  Widget _permissionsTab() {
    if (_loadingPermissions) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_permissionError != null) {
      return _errorState(_permissionError!, _loadPermissions);
    }
    if (_permissions.isEmpty) {
      return _emptyState(
        Icons.verified_user_outlined,
        'No recommendations right now',
        'Add permissions and security details to your accounts to get personalized advice.',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadPermissions,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _intro(
            'PERMISSION ADVISOR',
            'Keep only the access you need.',
            'Recommendations compare account permissions with the service category you recorded.',
          ),
          const SizedBox(height: 14),
          ..._permissions.map(
            (item) => _recommendationCard(item as Map<String, dynamic>),
          ),
        ],
      ),
    );
  }

  Widget _recommendationCard(Map<String, dynamic> item) {
    final unnecessary = (item['unnecessary_permissions'] as List?) ?? [];
    final advice = (item['advice'] as List?) ?? [];
    final high = item['priority'] == 'high';
    final color = high ? AppColors.red : AppColors.orange;
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item['service_name']?.toString() ?? 'Account',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              _pill('${item['priority'] ?? 'review'} priority', color),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Potential risk reduction: ${item['risk_reduction'] ?? 0} points',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          if (unnecessary.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Review these permissions',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: unnecessary
                  .map((p) => _pill(p.toString(), AppColors.red))
                  .toList(),
            ),
          ],
          if (advice.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...advice.map(
              (line) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.arrow_right,
                      size: 18,
                      color: AppColors.blue,
                    ),
                    Expanded(
                      child: Text(
                        line.toString(),
                        style: const TextStyle(fontSize: 13, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (item['ai_insight'] != null) ...[
            const SizedBox(height: 10),
            Text(
              item['ai_insight'].toString(),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _twinTab() {
    final data = _twin;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _intro(
          'DIGITAL TWIN',
          'Stress-test your account network.',
          'Simulations use your saved account links, password reuse groups, 2FA status, and permission records.',
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _loadingTwin ? null : _runTwin,
            icon: _loadingTwin
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(_loadingTwin ? 'Simulating…' : 'Run risk simulation'),
          ),
        ),
        if (_twinError != null) ...[
          const SizedBox(height: 12),
          _errorMessage(_twinError!),
        ],
        if (data != null) ...[
          const SizedBox(height: 16),
          if (data['error'] != null)
            _emptyState(
              Icons.account_tree_outlined,
              'Add accounts to begin',
              data['error'].toString(),
            ),
          if (data['error'] == null) ...[
            if (data['overall_risk_score'] != null)
              _card(
                Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: AppColors.blue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Average modeled attack probability: ${data['overall_risk_score']}%',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (data['ai_analysis'] != null)
              _card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Analysis',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data['ai_analysis'].toString(),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ...((data['attack_vectors'] as List?) ?? []).map((raw) {
              final vector = raw as Map<String, dynamic>;
              final probability = ((vector['success_probability'] as num?) ?? 0)
                  .toInt();
              return _card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            vector['vector']?.toString() ?? 'Threat scenario',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        _pill(
                          '$probability% modeled risk',
                          probability >= 60 ? AppColors.red : AppColors.orange,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      vector['description']?.toString() ?? '',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    if ((vector['targets'] as List?)?.isNotEmpty == true) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: (vector['targets'] as List)
                            .map(
                              (name) => _pill(
                                name.toString(),
                                AppColors.surfaceLight,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              );
            }),
            if (((data['attack_vectors'] as List?) ?? []).isEmpty)
              _emptyState(
                Icons.check_circle_outline,
                'No modeled attack paths found',
                'Keep your account inventory and security details up to date.',
              ),
            if ((data['recommendations'] as List?)?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              const Text(
                'Recommended next steps',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...(data['recommendations'] as List).map(
                (item) => _card(
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.checklist,
                        color: AppColors.green,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.toString(),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ],
    );
  }

  Widget _policyTab() {
    final result = _policy;
    final flags = (result?['risk_flags'] as Map<String, dynamic>?) ?? {};
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _intro(
          'POLICY WATCHDOG',
          'Read the privacy terms in plain English.',
          'Paste a service’s public policy URL. Analysis runs against the page content the service can retrieve.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _policyUrl,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Privacy policy URL',
            hintText: 'https://example.com/privacy',
            prefixIcon: Icon(Icons.link),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _analyzingPolicy ? null : _analyzePolicy,
            icon: _analyzingPolicy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.policy_outlined),
            label: Text(
              _analyzingPolicy ? 'Analyzing policy…' : 'Analyze policy',
            ),
          ),
        ),
        if (_policyError != null) ...[
          const SizedBox(height: 12),
          _errorMessage(_policyError!),
        ],
        if (result != null) ...[
          const SizedBox(height: 16),
          _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Policy risk: ${result['risk_score'] ?? 0}/100',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _pill(
                      (result['severity'] ?? result['status'] ?? 'review')
                          .toString(),
                      AppColors.orange,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  result['summary']?.toString() ?? 'No summary returned.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                if (result['recommendation'] != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    result['recommendation'].toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
                if (flags.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Detected topics',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ...flags.entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        children: [
                          Icon(
                            entry.value == true
                                ? Icons.warning_amber
                                : Icons.check_circle_outline,
                            size: 16,
                            color: entry.value == true
                                ? AppColors.orange
                                : AppColors.green,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.key.replaceAll('_', ' '),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        const Text(
          'Policy analysis is a point-in-time review. This screen does not yet track policy changes automatically.',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _intro(String eyebrow, String title, String body) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        eyebrow,
        style: const TextStyle(
          color: AppColors.blue,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.3,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        title,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 6),
      Text(
        body,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          height: 1.4,
        ),
      ),
    ],
  );

  Widget _card(Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );

  Widget _pill(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color.withAlpha(25),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );

  Widget _emptyState(IconData icon, String title, String body) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: AppColors.textMuted),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _errorMessage(String message) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.red.withAlpha(20),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      message,
      style: const TextStyle(color: AppColors.red, fontSize: 13),
    ),
  );

  Widget _errorState(String message, VoidCallback retry) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _errorMessage(message),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: retry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}
