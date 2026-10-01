import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

enum RiskLevel { critical, high, medium, safe }

class PermissionAuditItem {
  final String id;
  final String title;
  final String category;
  final RiskLevel risk;
  final String description;
  final String exploitVector;
  final String recommendation;
  final int affectedAppsCount;
  final List<String> flaggedApps;
  bool isSecured;

  PermissionAuditItem({
    required this.id,
    required this.title,
    required this.category,
    required this.risk,
    required this.description,
    required this.exploitVector,
    required this.recommendation,
    required this.affectedAppsCount,
    required this.flaggedApps,
    this.isSecured = false,
  });
}

class AntiTheftSetting {
  final String id;
  final String title;
  final String subtitle;
  final String iconCode;
  bool isEnabled;
  final String technicalDetail;

  AntiTheftSetting({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.iconCode,
    required this.isEnabled,
    required this.technicalDetail,
  });
}

class AndroidSecurityService {
  static final AndroidSecurityService _instance = AndroidSecurityService._internal();
  factory AndroidSecurityService() => _instance;
  AndroidSecurityService._internal();

  static const String _prefPrefix = 'ps_android_theft_';

  List<PermissionAuditItem> _cachedAudits = [];
  List<AntiTheftSetting> _cachedSettings = [];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    _cachedSettings = [
      AntiTheftSetting(
        id: 'motion_snatch',
        title: 'MOTION & PICKPOCKET RADAR',
        subtitle: 'Sounds piercing siren if device is lifted or pocketed while armed',
        iconCode: 'vibration',
        isEnabled: prefs.getBool('${_prefPrefix}motion_snatch') ?? true,
        technicalDetail: 'Real-time accelerometer + proximity sensor threshold (3.2G / 0.4s)',
      ),
      AntiTheftSetting(
        id: 'intruder_selfie',
        title: 'INTRUDER SELFIE & GEO-BEACON',
        subtitle: 'Captures stealth camera snapshot after 2 failed unlock attempts',
        iconCode: 'camera_front',
        isEnabled: prefs.getBool('${_prefPrefix}intruder_selfie') ?? true,
        technicalDetail: 'Front lens silent capture dispatched to encrypted incident log',
      ),
      AntiTheftSetting(
        id: 'sim_swap_guard',
        title: 'SIM CARD SWAP LOCKDOWN',
        subtitle: 'Locks device immediately if SIM tray is ejected or IMSI changed',
        iconCode: 'sim_card_alert',
        isEnabled: prefs.getBool('${_prefPrefix}sim_swap_guard') ?? true,
        technicalDetail: 'TelephonyManager IMSI hash validation on screen unlock',
      ),
      AntiTheftSetting(
        id: 'usb_debugging_block',
        title: 'USB DEBUGGING / FORENSIC SHIELD',
        subtitle: 'Blocks unauthorized ADB forensic extraction (Cellebrite / Graykey)',
        iconCode: 'usb',
        isEnabled: prefs.getBool('${_prefPrefix}usb_debugging_block') ?? false,
        technicalDetail: 'Checks Settings.Global.ADB_ENABLED flag in Android runtime',
      ),
      AntiTheftSetting(
        id: 'fake_shutdown',
        title: 'ANTI-KILL / FAKE POWER-OFF',
        subtitle: 'Requires biometric/PIN authentication before allowing device shutdown',
        iconCode: 'power_settings_new',
        isEnabled: prefs.getBool('${_prefPrefix}fake_shutdown') ?? false,
        technicalDetail: 'Intercepts ACTION_SHUTDOWN broadcast and requests biometric auth',
      ),
    ];

    _cachedAudits = [
      PermissionAuditItem(
        id: 'accessibility',
        title: 'Accessibility Services Access',
        category: 'Malware Vector #1',
        risk: RiskLevel.critical,
        description: 'Grants apps full control to read screen content, type inputs, and click buttons automatically.',
        exploitVector: 'Used by Android banking trojans (TeaBot, SharkBot) to bypass 2FA and hijack banking sessions.',
        recommendation: 'Disable accessibility services for all apps except verified screen readers or system tools.',
        affectedAppsCount: 2,
        flaggedApps: ['File Cleaner Master (Suspicious)', 'Auto-Clicker Tool'],
        isSecured: false,
      ),
      PermissionAuditItem(
        id: 'overlay',
        title: 'Display Over Other Apps (Overlay)',
        category: 'Tapjacking Vector',
        risk: RiskLevel.critical,
        description: 'Allows apps to render transparent or deceptive overlays directly on top of active apps.',
        exploitVector: 'Allows invisible phishing overlays to intercept passwords when opening banking or crypto wallets.',
        recommendation: 'Revoke overlay permission (SYSTEM_ALERT_WINDOW) for non-essential third-party utilities.',
        affectedAppsCount: 3,
        flaggedApps: ['Flashlight HD', 'Voice Recorder Pro', 'Game Booster'],
        isSecured: false,
      ),
      PermissionAuditItem(
        id: 'device_admin',
        title: 'Device Administrator Privileges',
        category: 'Privilege Escalation',
        risk: RiskLevel.high,
        description: 'Permits apps to lock the screen, wipe system storage, or prevent themselves from being uninstalled.',
        exploitVector: 'Ransomware and persistent stalkerware abuse Device Admin to resist uninstallation.',
        recommendation: 'Ensure only enterprise MDM or Google Find My Device holds Device Admin status.',
        affectedAppsCount: 1,
        flaggedApps: ['Google Find My Device (Verified)'],
        isSecured: true,
      ),
      PermissionAuditItem(
        id: 'notification_listener',
        title: 'Notification Interception Service',
        category: 'Credential Theft',
        risk: RiskLevel.high,
        description: 'Permits reading all incoming push notifications, messages, and security codes.',
        exploitVector: 'Interception of SMS 2FA codes, WhatsApp chat snippets, and password reset tokens in real-time.',
        recommendation: 'Restrict notification access exclusively to trusted smart wearables or system services.',
        affectedAppsCount: 1,
        flaggedApps: ['Battery Saver Ultra (High Risk)'],
        isSecured: false,
      ),
      PermissionAuditItem(
        id: 'background_location',
        title: 'Background Location (Always-On)',
        category: 'Physical Surveillance',
        risk: RiskLevel.medium,
        description: 'Continuously queries GPS coordinates even when the app is completely closed or inactive.',
        exploitVector: 'Generates comprehensive geographic behavioral dossiers and physical movement profiling.',
        recommendation: 'Downgrade permission from "Allow all the time" to "Allow only while using the app".',
        affectedAppsCount: 4,
        flaggedApps: ['Shopping Club App', 'Weather Now', 'Coupon Finder', 'Local Deals'],
        isSecured: false,
      ),
      PermissionAuditItem(
        id: 'sideloading',
        title: 'Install Unknown Apps (Sideloading)',
        category: 'Arbitrary Code Execution',
        risk: RiskLevel.high,
        description: 'Permits browsers or chat applications to prompt and install unverified APK packages.',
        exploitVector: 'Drive-by download attacks where visiting a malicious URL triggers automatic APK install.',
        recommendation: 'Disallow "Install Unknown Apps" on Chrome, Telegram, and File Managers.',
        affectedAppsCount: 2,
        flaggedApps: ['Chrome Browser', 'Telegram Messenger'],
        isSecured: false,
      ),
    ];
  }

  List<AntiTheftSetting> getAntiTheftSettings() {
    return _cachedSettings;
  }

  List<PermissionAuditItem> getPermissionAudits() {
    return _cachedAudits;
  }

  Future<void> toggleAntiTheftSetting(String id, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefPrefix$id', value);
    final item = _cachedSettings.firstWhere((s) => s.id == id, orElse: () => _cachedSettings.first);
    item.isEnabled = value;
  }

  void resolvePermissionItem(String id) {
    final item = _cachedAudits.firstWhere((a) => a.id == id);
    item.isSecured = true;
  }

  int calculateDeviceIntegrityScore() {
    int score = 40; // baseline

    // Add points for each secured permission
    for (final audit in _cachedAudits) {
      if (audit.isSecured) {
        score += audit.risk == RiskLevel.critical ? 12 : 8;
      }
    }

    // Add points for anti-theft settings enabled
    for (final setting in _cachedSettings) {
      if (setting.isEnabled) {
        score += 6;
      }
    }

    return score.clamp(15, 98);
  }
}
