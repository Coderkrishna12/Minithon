import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../services/server_discovery.dart';

class ServerSetupScreen extends StatefulWidget {
  const ServerSetupScreen({super.key});

  @override
  State<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _ServerSetupScreenState extends State<ServerSetupScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _controller.text = ServerDiscovery.baseUrl;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _done() async {
    if (!mounted) return;
    if (Navigator.canPop(context)) {
      Navigator.pop(context, true);
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Future<void> _search() async {
    setState(() {
      _busy = true;
      _message = 'Searching this Wi-Fi network…';
    });
    final found = await ServerDiscovery.discover(includeSaved: false);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = found == null ? 'No PrivacyShield server answered on this network.' : 'Connected to $found';
    });
    if (found != null) await _done();
  }

  Future<void> _connect() async {
    final base = ServerDiscovery.normalize(_controller.text);
    setState(() {
      _busy = true;
      _message = 'Trying $base…';
    });
    final ok = await ServerDiscovery.probe(base, timeout: const Duration(seconds: 4));
    if (!mounted) return;
    if (ok) {
      await ServerDiscovery.use(base);
      await _done();
      return;
    }
    setState(() {
      _busy = false;
      _message = 'No answer from $base. Open $base/health in the phone\'s browser to test.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Server')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('CONNECTION', style: AppText.eyebrow()),
            const SizedBox(height: 10),
            Text("Can't reach your PrivacyShield server.", style: AppText.serif(size: 34)),
            const SizedBox(height: 16),
            const Text('On the PC, in the backend folder, run:', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              color: AppColors.ink,
              child: Text('python run.py', style: AppText.mono(size: 14, color: AppColors.surface)),
            ),
            const SizedBox(height: 8),
            const Text(
              'It opens the firewall, prints the address to use, and sets up USB if the phone is plugged in. '
              'Keep the phone on the same Wi-Fi as the PC, then search again.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 12),
            const Text(
              "If the phone's browser says the site can't be reached, the Wi-Fi is blocking it. Run this instead "
              'and type the https address it prints below:',
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              color: AppColors.ink,
              child: Text('python run.py --public', style: AppText.mono(size: 14, color: AppColors.surface)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _busy ? null : _search, child: const Text('Search again')),
            const SizedBox(height: 28),
            Text('OR ENTER THE ADDRESS', style: AppText.eyebrow()),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(hintText: '192.168.1.5 or https://name.trycloudflare.com'),
              onSubmitted: (_) => _connect(),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _busy ? null : _connect, child: const Text('Connect')),
            if (_message != null) ...[
              const SizedBox(height: 20),
              Row(children: [
                if (_busy) ...[
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 10),
                ],
                Expanded(child: Text(_message!, style: const TextStyle(color: AppColors.textSecondary))),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}
