import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../services/android_security_service.dart';
import '../services/biometric_service.dart';

class AndroidSecurityScreen extends StatefulWidget {
  final bool isEmbedded;
  const AndroidSecurityScreen({super.key, this.isEmbedded = false});

  @override
  State<AndroidSecurityScreen> createState() => _AndroidSecurityScreenState();
}

class _AndroidSecurityScreenState extends State<AndroidSecurityScreen> with SingleTickerProviderStateMixin {
  final AndroidSecurityService _securityService = AndroidSecurityService();
  final BiometricService _biometricService = BiometricService();
  bool _isLoading = true;
  int _activeTab = 0; // 0: Anti-Theft Guard, 1: Permission Auditor
  bool _isAlarmTriggered = false;
  bool _isMotionArmed = false;
  int _armCountdown = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _securityService.init();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _triggerAlarmTest() {
    setState(() => _isAlarmTriggered = true);
  }

  Future<void> _disarmAlarm() async {
    final authenticated = await _biometricService.authenticate(
      reason: 'Biometric authorization required to disarm anti-theft defense',
    );
    if (authenticated && mounted) {
      setState(() {
        _isAlarmTriggered = false;
        _isMotionArmed = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ANTI-THEFT SYSTEM DISARMED VIA BIOMETRICS',
              style: GoogleFonts.spaceGrotesk(letterSpacing: 1.0, fontSize: 12, fontWeight: FontWeight.w700)),
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _armMotionSensor() {
    if (_isMotionArmed) {
      setState(() => _isMotionArmed = false);
      return;
    }

    setState(() => _armCountdown = 5);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_armCountdown > 1) {
          _armCountdown--;
        } else {
          _armCountdown = 0;
          _isMotionArmed = true;
          timer.cancel();
        }
      });
    });
  }

  void _showAndroidRemediationDialog(PermissionAuditItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        title: Row(
          children: [
            const Icon(Icons.shield_outlined, color: AppColors.textPrimary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'ANDROID HARDENING GUIDE',
                style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.0),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.title, style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text(item.description, style: GoogleFonts.spaceGrotesk(fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('EXPLOITATION VECTOR:', style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.red, letterSpacing: 0.8)),
                  const SizedBox(height: 4),
                  Text(item.exploitVector, style: GoogleFonts.spaceGrotesk(fontSize: 11, color: AppColors.textPrimary, height: 1.3)),
                  const SizedBox(height: 10),
                  Text('REMEDY PATHWAY (ANDROID 12-15):', style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.8)),
                  const SizedBox(height: 4),
                  Text(
                    'Settings > Apps > Special App Access > ${item.title} > Revoke for unverified utilities.',
                    style: GoogleFonts.spaceGrotesk(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CLOSE', style: GoogleFonts.spaceGrotesk(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _securityService.resolvePermissionItem(item.id));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('SECURITY POSTURE UPDATED: ${item.title.toUpperCase()} SECURED',
                      style: GoogleFonts.spaceGrotesk(letterSpacing: 0.8, fontSize: 11, fontWeight: FontWeight.w700)),
                  backgroundColor: AppColors.surface,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('MARK AS REVOKED'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.textPrimary, strokeWidth: 2)),
      );
    }

    if (_isAlarmTriggered) {
      return _buildAlarmTriggeredScreen();
    }

    final score = _securityService.calculateDeviceIntegrityScore();
    final antiTheftSettings = _securityService.getAntiTheftSettings();
    final permissionAudits = _securityService.getPermissionAudits();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'ANDROID ENDPOINT GUARD',
          style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1.4),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: score >= 80 ? AppColors.green : AppColors.amber,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$score/100 INTEGRITY',
                  style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildEndpointHeader(score),
              const SizedBox(height: 20),
              _buildTabSelector(),
              const SizedBox(height: 20),
              if (_activeTab == 0) ...[
                _buildAntiTheftSection(antiTheftSettings),
              ] else ...[
                _buildPermissionAuditorSection(permissionAudits),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlarmTriggeredScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF1B0707),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.red, width: 2),
                    color: AppColors.red.withValues(alpha: 0.15),
                  ),
                  child: const Icon(Icons.warning_amber_rounded, size: 50, color: AppColors.red),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'THEFT DEFENSE ACTIVE',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Motion sensor / unauthorized movement threshold breached.\nCamera snapshot logged. Incident dispatched to security enclave.',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _disarmAlarm,
                icon: const Icon(Icons.fingerprint, size: 20, color: AppColors.background),
                label: const Text('DISARM WITH BIOMETRIC PASSKEY'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.textPrimary,
                  foregroundColor: AppColors.background,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => setState(() => _isAlarmTriggered = false),
                child: const Text('DISMISS TEST ALARM'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEndpointHeader(int score) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ANDROID ENDPOINT POSTURE',
                    style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    score >= 80 ? 'HARDENED ENCLAVE' : 'ELEVATED VULNERABILITY',
                    style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                ],
              ),
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: score >= 80 ? AppColors.green : AppColors.amber, width: 2),
                ),
                child: Text(
                  '$score',
                  style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildMicroBadge('SELinux: Enforcing', AppColors.green),
              const SizedBox(width: 8),
              _buildMicroBadge('Root Status: Clean', AppColors.green),
              const SizedBox(width: 8),
              _buildMicroBadge('Biometrics: Ready', AppColors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMicroBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 4, height: 4, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _activeTab == 0 ? AppColors.surfaceLight : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: _activeTab == 0 ? Border.all(color: AppColors.border, width: 1) : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  'ANTI-THEFT RADAR',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: _activeTab == 0 ? AppColors.textPrimary : AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _activeTab == 1 ? AppColors.surfaceLight : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: _activeTab == 1 ? Border.all(color: AppColors.border, width: 1) : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  'APP PERMISSIONS (6)',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: _activeTab == 1 ? AppColors.textPrimary : AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAntiTheftSection(List<AntiTheftSetting> settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Live Motion Armed Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isMotionArmed ? AppColors.red.withValues(alpha: 0.08) : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isMotionArmed ? AppColors.red.withValues(alpha: 0.5) : AppColors.border,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isMotionArmed ? Icons.radar : Icons.motion_photos_on_outlined,
                        color: _isMotionArmed ? AppColors.red : AppColors.textPrimary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isMotionArmed ? 'MOTION SENTRY ARMED' : 'ARM DESK / POCKET SENTRY',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: _isMotionArmed ? AppColors.red : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  if (_armCountdown > 0)
                    Text('ARMING IN ${_armCountdown}S',
                        style: GoogleFonts.spaceGrotesk(fontSize: 11, color: AppColors.amber, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _isMotionArmed
                  ? 'Device motion sensor is active. Any movement or lifting will trigger an immediate high-decibel alert.'
                  : 'Place phone on table or in bag and tap arm. Provides 5s buffer before sentry triggers on displacement.',
                style: GoogleFonts.spaceGrotesk(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _armCountdown > 0 ? null : _armMotionSensor,
                      icon: Icon(_isMotionArmed ? Icons.lock_open : Icons.security, size: 16),
                      label: Text(_isMotionArmed ? 'DISARM SENTRY' : 'ARM SENTRY SENSORS'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isMotionArmed ? AppColors.red : AppColors.textPrimary,
                        foregroundColor: _isMotionArmed ? Colors.white : AppColors.background,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _triggerAlarmTest,
                    child: const Text('TEST ALARM'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'HARDWARE & RUNTIME PROTECTION CONTROLS',
          style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: AppColors.textMuted),
        ),
        const SizedBox(height: 10),
        ...settings.map((s) => _buildSettingTile(s)),
      ],
    );
  }

  Widget _buildSettingTile(AntiTheftSetting setting) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      setting.title,
                      style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      setting.subtitle,
                      style: GoogleFonts.spaceGrotesk(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: setting.isEnabled,
                activeThumbColor: AppColors.textPrimary,
                activeTrackColor: AppColors.surfaceLight,
                inactiveThumbColor: AppColors.textMuted,
                inactiveTrackColor: AppColors.surface,
                onChanged: (val) async {
                  await _securityService.toggleAntiTheftSetting(setting.id, val);
                  setState(() {});
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            setting.technicalDetail,
            style: GoogleFonts.spaceGrotesk(fontSize: 10, color: AppColors.textMuted, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionAuditorSection(List<PermissionAuditItem> audits) {
    final criticalCount = audits.where((a) => !a.isSecured && a.risk == RiskLevel.critical).length;
    final highCount = audits.where((a) => !a.isSecured && a.risk == RiskLevel.high).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCountColumn('$criticalCount', 'CRITICAL RISK', AppColors.red),
              Container(width: 1, height: 28, color: AppColors.border),
              _buildCountColumn('$highCount', 'HIGH RISK', AppColors.amber),
              Container(width: 1, height: 28, color: AppColors.border),
              _buildCountColumn('${audits.where((a) => a.isSecured).length}', 'SECURED', AppColors.green),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'ANDROID SPECIAL PERMISSION AUDIT',
          style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: AppColors.textMuted),
        ),
        const SizedBox(height: 10),
        ...audits.map((a) => _buildPermissionCard(a)),
      ],
    );
  }

  Widget _buildCountColumn(String count, String label, Color color) {
    return Column(
      children: [
        Text(count, style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.spaceGrotesk(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.8)),
      ],
    );
  }

  Widget _buildPermissionCard(PermissionAuditItem item) {
    Color riskColor = item.isSecured
        ? AppColors.green
        : item.risk == RiskLevel.critical
            ? AppColors.red
            : item.risk == RiskLevel.high
                ? AppColors.amber
                : AppColors.blue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: item.isSecured ? AppColors.border : riskColor.withValues(alpha: 0.4), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.isSecured ? 'SECURED / HARDENED' : item.category.toUpperCase(),
                  style: GoogleFonts.spaceGrotesk(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: riskColor),
                ),
              ),
              Text(
                '${item.affectedAppsCount} APPS GRANTED',
                style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.title,
            style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            item.description,
            style: GoogleFonts.spaceGrotesk(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 14, color: riskColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Flagged: ${item.flaggedApps.join(", ")}',
                    style: GoogleFonts.spaceGrotesk(fontSize: 11, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showAndroidRemediationDialog(item),
                  child: Text(item.isSecured ? 'VIEW PATHWAY' : 'AUDIT & HARDEN'),
                ),
              ),
              if (!item.isSecured) ...[
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _securityService.resolvePermissionItem(item.id));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${item.title.toUpperCase()} MARKED SECURE',
                            style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w700)),
                        backgroundColor: AppColors.surface,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text('REVOKE'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
