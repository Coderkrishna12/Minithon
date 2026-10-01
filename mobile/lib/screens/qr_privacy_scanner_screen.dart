import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../config/theme.dart';
import '../services/api_service.dart';

class QrPrivacyScannerScreen extends StatefulWidget {
  const QrPrivacyScannerScreen({super.key});

  @override
  State<QrPrivacyScannerScreen> createState() => _QrPrivacyScannerScreenState();
}

class _QrPrivacyScannerScreenState extends State<QrPrivacyScannerScreen> {
  final _api = ApiService();
  late final MobileScannerController _controller;
  Map<String, dynamic>? _scan;
  Map<String, dynamic>? _account;
  bool _lookingUp = false;
  bool _adding = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [BarcodeFormat.qrCode],
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_lookingUp || _scan != null) return;
    final raw = capture.barcodes.firstOrNull?.rawValue?.trim();
    if (raw == null || raw.isEmpty) return;
    final uri = Uri.tryParse(raw);
    final isUrl =
        uri != null &&
        {'http', 'https'}.contains(uri.scheme) &&
        uri.host.isNotEmpty;
    final safeUrl = isUrl
        ? Uri(
            scheme: uri.scheme,
            host: uri.host,
            port: uri.hasPort ? uri.port : null,
          ).toString()
        : null;
    setState(() {
      _lookingUp = true;
      _scan = {
        'url': safeUrl,
        'host': isUrl
            ? uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '')
            : null,
        'secure': isUrl && uri.scheme == 'https',
        'recognized': isUrl,
      };
      _error = null;
    });
    await _controller.stop();
    if (!isUrl) {
      if (mounted) setState(() => _lookingUp = false);
      return;
    }
    try {
      final accounts = await _api.getList('/accounts/');
      final host = (uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), ''));
      final match = accounts.cast<Map<String, dynamic>?>().where((account) {
        if (account == null) return false;
        final serviceUrl = Uri.tryParse(
          (account['service_url'] ?? '').toString(),
        );
        final savedHost =
            (serviceUrl?.host.isNotEmpty == true
                    ? serviceUrl!.host
                    : (account['service_url'] ?? '').toString())
                .toLowerCase()
                .replaceFirst(RegExp(r'^www\.'), '');
        return savedHost.isNotEmpty &&
            (host == savedHost ||
                host.endsWith('.$savedHost') ||
                savedHost.endsWith('.$host'));
      }).firstOrNull;
      if (mounted) setState(() => _account = match);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error =
              'Could not compare this QR code with your account inventory: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  Future<void> _addAccount() async {
    final scan = _scan;
    if (scan == null || scan['url'] == null || _adding) return;
    final host = scan['host'].toString();
    final name = host.split('.').where((part) => part.isNotEmpty).first;
    setState(() => _adding = true);
    try {
      await _api.post(
        '/accounts/',
        body: {
          'service_name': name[0].toUpperCase() + name.substring(1),
          'service_url': scan['url'],
          'category': 'other',
          'login_method': 'password',
          'has_2fa': false,
          'notes':
              'Added after scanning a QR code. Confirm this service and its security details.',
        },
      );
      if (!mounted) return;
      final accounts = await _api.getList('/accounts/');
      if (!mounted) return;
      setState(() {
        _account = accounts
            .cast<Map<String, dynamic>?>()
            .where(
              (account) => account?['service_url']?.toString() == scan['url'],
            )
            .firstOrNull;
        _adding = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Service added. Review its details in Accounts.'),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _adding = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not add service: $e')));
      }
    }
  }

  Future<void> _scanAgain() async {
    setState(() {
      _scan = null;
      _account = null;
      _error = null;
    });
    await _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    final scan = _scan;
    return Scaffold(
      appBar: AppBar(title: const Text('QR Privacy Check')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: scan == null ? 3 : 2,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (scan == null)
                    MobileScanner(
                      controller: _controller,
                      onDetect: _onDetect,
                      onDetectError: (error, _) =>
                          setState(() => _error = error.toString()),
                      errorBuilder: (context, error) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Camera unavailable: ${error.errorCode.name}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      color: AppColors.ink,
                      child: const Center(
                        child: Icon(
                          Icons.qr_code_2,
                          size: 96,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  if (scan == null)
                    Center(
                      child: Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  if (scan == null)
                    const Positioned(
                      left: 20,
                      right: 20,
                      bottom: 20,
                      child: Text(
                        'Point your camera at an app or device QR code',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.red, fontSize: 12),
                ),
              ),
            if (scan != null) Expanded(flex: 2, child: _resultPanel(scan)),
            if (scan != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _scanAgain,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan another code'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _resultPanel(Map<String, dynamic> scan) {
    final host = scan['host']?.toString();
    final account = _account;
    if (_lookingUp) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(
          scan['recognized'] == true ? 'QR destination' : 'QR code scanned',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          scan['recognized'] == true
              ? host!
              : 'This code does not contain a web address. Its contents were not sent to PrivacyShield.',
          style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        if (scan['recognized'] == true) ...[
          const SizedBox(height: 14),
          _infoCard(Icons.link, 'Destination', scan['url'].toString()),
          _infoCard(
            scan['secure'] == true ? Icons.lock : Icons.warning_amber,
            scan['secure'] == true ? 'Connection' : 'Transport warning',
            scan['secure'] == true
                ? 'HTTPS address'
                : 'This QR code uses HTTP. Avoid entering passwords or personal data.',
          ),
          if (account != null) ...[
            _infoCard(
              Icons.account_circle_outlined,
              'In your inventory',
              account['service_name']?.toString() ?? 'Tracked account',
            ),
            _infoCard(
              Icons.shield_outlined,
              'Current account risk',
              '${(account['risk_score'] as num? ?? 0).round()}/100 · ${account['has_2fa'] == true ? '2FA on' : '2FA off'} · ${account['breach_count'] ?? 0} breach records',
            ),
            const SizedBox(height: 8),
            const Text(
              'The QR destination is shown for review only. PrivacyShield will not open it automatically.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ] else ...[
            const SizedBox(height: 8),
            const Text(
              'This destination is not in your account inventory yet. Confirm the service before adding it.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _adding ? null : _addAccount,
              icon: _adding
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add),
              label: Text(_adding ? 'Adding…' : 'Add to account inventory'),
            ),
          ],
        ] else
          _infoCard(
            Icons.privacy_tip_outlined,
            'Privacy',
            'Non-URL QR contents stay on this device and are not displayed.',
          ),
      ],
    );
  }

  Widget _infoCard(IconData icon, String title, String detail) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.blue, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                detail,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
