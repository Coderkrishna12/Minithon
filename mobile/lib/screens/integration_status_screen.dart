import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/api_service.dart';

class IntegrationStatusScreen extends StatefulWidget {
  const IntegrationStatusScreen({super.key});
  @override
  State<IntegrationStatusScreen> createState() => _IntegrationStatusScreenState();
}

class _IntegrationStatusScreenState extends State<IntegrationStatusScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _api.get('/v1/status');
      if (mounted) setState(() { _data = result; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final integrations = (_data?['integrations'] as Map?)?.cast<String, dynamic>() ?? {};
    return Scaffold(
      appBar: AppBar(title: const Text('Connection status'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: _loading ? const Center(child: CircularProgressIndicator(color: AppColors.blue))
          : _error != null ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.cloud_off, size: 40), const SizedBox(height: 12), Text(_error!), const SizedBox(height: 12), ElevatedButton(onPressed: _load, child: const Text('Try again'))])))
          : RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: [
              const Text('Provider status is based on configuration and the latest observed call. A configured provider is not proof that it is currently reachable.', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              ...integrations.entries.map((entry) {
                final value = (entry.value as Map).cast<String, dynamic>();
                final name = entry.key.toUpperCase();
                final mode = value['mode'] ?? 'unknown';
                final health = value['health'] ?? 'not checked';
                final color = health == 'healthy' ? AppColors.green : health == 'mock' || health == 'local_only' ? AppColors.orange : AppColors.textMuted;
                return Card(color: AppColors.surface, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold))), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(8)), child: Text('$health', style: TextStyle(color: color, fontSize: 12))) ]),
                  const SizedBox(height: 8),
                  Text('Mode: $mode · configured: ${value['configured'] == true ? 'yes' : 'no'}'),
                  if (value['latency_ms'] != null) Text('Last call latency: ${value['latency_ms']} ms'),
                  if (value['last_successful_call'] != null) Text('Last successful call: ${value['last_successful_call']}'),
                  if (value['detail'] != null) Text('${value['detail']}', style: const TextStyle(color: AppColors.textSecondary)),
                ])));
              }),
              const SizedBox(height: 8),
              const Text('Fixture results are demonstrations, not verified findings about your accounts.', style: TextStyle(color: AppColors.orange, fontSize: 12)),
            ])),
    );
  }
}
