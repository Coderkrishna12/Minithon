import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../services/device_audit.dart';

const _headlineCapabilities = [
  Capability.microphone,
  Capability.camera,
  Capability.location,
  Capability.backgroundLocation,
  Capability.contacts,
  Capability.sms,
];

class DeviceAuditScreen extends StatefulWidget {
  final DeviceAuditService? service;
  final bool embedded;

  const DeviceAuditScreen({super.key, this.service, this.embedded = false});

  @override
  State<DeviceAuditScreen> createState() => _DeviceAuditScreenState();
}

class _DeviceAuditScreenState extends State<DeviceAuditScreen> with WidgetsBindingObserver {
  late final DeviceAuditService _service = widget.service ?? DeviceAuditService();
  List<AppAudit> _apps = [];
  DevicePosture? _posture;
  bool _loading = true;
  bool _includeSystem = false;
  Capability? _filter;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scan();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _scan(quiet: true);
  }

  Future<void> _scan({bool quiet = false}) async {
    if (!_service.supported) {
      setState(() => _loading = false);
      return;
    }
    if (!quiet) setState(() => _loading = true);
    try {
      final results = await Future.wait([_service.scanApps(), _service.posture()]);
      if (!mounted) return;
      setState(() {
        _apps = results[0] as List<AppAudit>;
        _posture = results[1] as DevicePosture;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not read this phone: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<AppAudit> get _visible => _apps.where((a) => _includeSystem || !a.system).toList();

  int _count(Capability c) => _visible.where((a) => a.capabilities.contains(c)).length;

  String _plural(int n, String one, String many) => n == 1 ? '1 $one' : '$n $many';

  (String, String) get _headline {
    final listeners = _visible.where((a) => a.notificationListener).length;
    if (listeners > 0) {
      return (_plural(listeners, 'app can', 'apps can'), 'read every notification, including your 2FA codes.');
    }
    final mic = _count(Capability.microphone);
    return (_plural(mic, 'app on this phone can', 'apps on this phone can'), 'turn on your microphone.');
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody();
    if (widget.embedded) return body;
    return Scaffold(appBar: AppBar(title: const Text('Device audit')), body: body);
  }

  Widget _buildBody() {
    if (!_service.supported) {
      return _Message(
        eyebrow: 'Android only',
        title: 'This check reads the phone itself.',
        body: 'Install PrivacyShield on an Android phone to see which apps can use your microphone, camera, location, SMS and notifications.',
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _Message(eyebrow: 'Scan failed', title: 'Something went wrong.', body: _error!);
    }

    final (lead, rest) = _headline;
    final privileged = _visible.where((a) => a.privileged).toList();
    final apps = _filter == null ? _visible : _visible.where((a) => a.capabilities.contains(_filter)).toList();

    return RefreshIndicator(
      color: AppColors.ink,
      onRefresh: _scan,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          Text('EXHIBIT B · THIS PHONE', style: AppText.eyebrow()),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: '$lead ', style: AppText.serif(size: 38, color: AppColors.red)),
              TextSpan(text: rest, style: AppText.serif(size: 38)),
            ]),
          ),
          const SizedBox(height: 10),
          Text(
            '${_visible.length} apps checked on ${_posture?.device ?? 'this phone'} · ${_posture?.android ?? ''}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),
          _CapabilityGrid(
            counts: {for (final c in _headlineCapabilities) c: _count(c)},
            selected: _filter,
            onTap: (c) => setState(() => _filter = _filter == c ? null : c),
          ),
          if (privileged.isNotEmpty) ...[
            const SizedBox(height: 32),
            _SectionTitle('Privileged access', '${privileged.length}'),
            for (final a in privileged) _PrivilegedRow(app: a, onOpen: _openPrivilegedSettings),
          ],
          if (_posture != null) ...[
            const SizedBox(height: 32),
            _SectionTitle('Device posture', '${_posture!.checks.where((c) => !c.ok).length} to fix'),
            for (final c in _posture!.checks) _PostureRow(check: c, onFix: () => _service.openSettings(c.settingsScreen)),
          ],
          const SizedBox(height: 32),
          _SectionTitle(_filter == null ? 'Apps by risk' : 'Apps with ${_filter!.label.toLowerCase()} access', '${apps.length}'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeThumbColor: AppColors.ink,
            title: const Text('Include system apps', style: TextStyle(fontSize: 14)),
            value: _includeSystem,
            onChanged: (v) => setState(() => _includeSystem = v),
          ),
          for (final a in apps) _AppRow(app: a, onTap: () => _showApp(a)),
        ],
      ),
    );
  }

  void _openPrivilegedSettings(AppAudit a) {
    if (a.notificationListener) {
      _service.openSettings('notification_listeners');
    } else if (a.accessibility) {
      _service.openSettings('accessibility');
    } else {
      _service.openSettings('device_admin');
    }
  }

  void _showApp(AppAudit a) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(6))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a.package, style: AppText.eyebrow()),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: Text(a.label, style: AppText.serif(size: 32))),
                  Text('${a.risk}', style: AppText.serif(size: 32, color: _riskColor(a.risk))),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(spacing: 6, runSpacing: 6, children: [for (final c in a.capabilities) _Chip(c.label)]),
              const SizedBox(height: 14),
              for (final f in a.findings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(width: 7, height: 7, margin: const EdgeInsets.only(top: 6, right: 10), color: _severityColor(f.severity)),
                    Expanded(child: Text(f.text, style: const TextStyle(fontSize: 14, height: 1.35))),
                  ]),
                ),
              if (a.findings.isEmpty && a.capabilities.isEmpty)
                const Text('No sensitive permissions granted.', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _service.openAppSettings(a.package);
                  },
                  child: const Text('Revoke in Android settings'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _riskColor(int risk) => risk >= 50 ? AppColors.red : risk >= 25 ? AppColors.orange : AppColors.green;

Color _severityColor(Severity s) => switch (s) {
      Severity.critical => AppColors.red,
      Severity.high => AppColors.orange,
      Severity.medium => AppColors.textMuted,
    };

class _Message extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String body;
  const _Message({required this.eyebrow, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eyebrow.toUpperCase(), style: AppText.eyebrow()),
          const SizedBox(height: 12),
          Text(title, style: AppText.serif(size: 34)),
          const SizedBox(height: 12),
          Text(body, style: const TextStyle(color: AppColors.textSecondary, height: 1.45)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String meta;
  const _SectionTitle(this.title, this.meta);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.ink))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: Text(title, style: AppText.serif(size: 24))),
          Text(meta.toUpperCase(), style: AppText.eyebrow()),
        ],
      ),
    );
  }
}

class _CapabilityGrid extends StatelessWidget {
  final Map<Capability, int> counts;
  final Capability? selected;
  final ValueChanged<Capability> onTap;
  const _CapabilityGrid({required this.counts, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.05,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        for (final e in counts.entries)
          GestureDetector(
            onTap: () => onTap(e.key),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected == e.key ? AppColors.ink : AppColors.surface,
                border: Border.all(color: selected == e.key ? AppColors.ink : AppColors.border),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${e.value}',
                    style: AppText.serif(
                      size: 38,
                      color: selected == e.key ? AppColors.surface : (e.value > 0 ? AppColors.textPrimary : AppColors.textMuted),
                    ),
                  ),
                  Text(
                    e.key.label.toUpperCase(),
                    style: AppText.eyebrow(color: selected == e.key ? AppColors.borderHover : AppColors.textMuted),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PrivilegedRow extends StatelessWidget {
  final AppAudit app;
  final ValueChanged<AppAudit> onOpen;
  const _PrivilegedRow({required this.app, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final what = [
      if (app.notificationListener) 'Reads notifications',
      if (app.accessibility) 'Accessibility',
      if (app.deviceAdmin) 'Device admin',
    ].join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(width: 8, height: 8, color: AppColors.red),
      minLeadingWidth: 8,
      title: Text(app.label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(what, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      trailing: TextButton(onPressed: () => onOpen(app), child: const Text('Review')),
    );
  }
}

class _PostureRow extends StatelessWidget {
  final PostureCheck check;
  final VoidCallback onFix;
  const _PostureRow({required this.check, required this.onFix});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(check.ok ? Icons.check : Icons.close, color: check.ok ? AppColors.green : _severityColor(check.severity), size: 20),
      minLeadingWidth: 20,
      title: Text(check.title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(check.detail, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      trailing: check.ok ? null : TextButton(onPressed: onFix, child: const Text('Fix')),
    );
  }
}

class _AppRow extends StatelessWidget {
  final AppAudit app;
  final VoidCallback onTap;
  const _AppRow({required this.app, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 44,
              child: Text('${app.risk}', style: AppText.serif(size: 26, color: _riskColor(app.risk))),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(child: Text(app.label, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                    if (app.sideloaded) ...[const SizedBox(width: 6), const _Chip('Sideloaded', warn: true)],
                  ]),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final c in app.capabilities.where(_headlineCapabilities.contains)) _Chip(c.label),
                      if (app.capabilities.where(_headlineCapabilities.contains).isEmpty)
                        const Text('No sensitive access', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                  if (app.findings.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(app.findings.first.text, style: TextStyle(color: _severityColor(app.findings.first.severity), fontSize: 12.5)),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool warn;
  const _Chip(this.label, {this.warn = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: warn ? AppColors.red : AppColors.borderHover),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(label.toUpperCase(), style: AppText.eyebrow(color: warn ? AppColors.red : AppColors.textSecondary).copyWith(fontSize: 9.5)),
    );
  }
}
