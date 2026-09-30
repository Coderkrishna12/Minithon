import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum Capability {
  microphone('Microphone', 15),
  camera('Camera', 10),
  location('Location', 10),
  backgroundLocation('Background location', 25),
  contacts('Contacts', 10),
  sms('SMS', 20),
  callLogs('Call logs', 20),
  phone('Phone', 6),
  calendar('Calendar', 5),
  bodySensors('Body sensors', 8),
  media('Photos & files', 4),
  nearby('Nearby devices', 3);

  const Capability(this.label, this.weight);
  final String label;
  final int weight;
}

const _p = 'android.permission.';

const Map<String, Capability> permissionCapabilities = {
  '${_p}RECORD_AUDIO': Capability.microphone,
  '${_p}CAMERA': Capability.camera,
  '${_p}ACCESS_FINE_LOCATION': Capability.location,
  '${_p}ACCESS_COARSE_LOCATION': Capability.location,
  '${_p}ACCESS_BACKGROUND_LOCATION': Capability.backgroundLocation,
  '${_p}READ_CONTACTS': Capability.contacts,
  '${_p}WRITE_CONTACTS': Capability.contacts,
  '${_p}GET_ACCOUNTS': Capability.contacts,
  '${_p}READ_SMS': Capability.sms,
  '${_p}RECEIVE_SMS': Capability.sms,
  '${_p}SEND_SMS': Capability.sms,
  '${_p}RECEIVE_MMS': Capability.sms,
  '${_p}RECEIVE_WAP_PUSH': Capability.sms,
  '${_p}READ_CALL_LOG': Capability.callLogs,
  '${_p}WRITE_CALL_LOG': Capability.callLogs,
  '${_p}PROCESS_OUTGOING_CALLS': Capability.callLogs,
  '${_p}READ_PHONE_STATE': Capability.phone,
  '${_p}READ_PHONE_NUMBERS': Capability.phone,
  '${_p}CALL_PHONE': Capability.phone,
  '${_p}ANSWER_PHONE_CALLS': Capability.phone,
  '${_p}READ_CALENDAR': Capability.calendar,
  '${_p}WRITE_CALENDAR': Capability.calendar,
  '${_p}BODY_SENSORS': Capability.bodySensors,
  '${_p}BODY_SENSORS_BACKGROUND': Capability.bodySensors,
  '${_p}ACTIVITY_RECOGNITION': Capability.bodySensors,
  '${_p}READ_EXTERNAL_STORAGE': Capability.media,
  '${_p}WRITE_EXTERNAL_STORAGE': Capability.media,
  '${_p}READ_MEDIA_IMAGES': Capability.media,
  '${_p}READ_MEDIA_VIDEO': Capability.media,
  '${_p}READ_MEDIA_AUDIO': Capability.media,
  '${_p}BLUETOOTH_SCAN': Capability.nearby,
  '${_p}BLUETOOTH_CONNECT': Capability.nearby,
  '${_p}NEARBY_WIFI_DEVICES': Capability.nearby,
  '${_p}UWB_RANGING': Capability.nearby,
};

/// What an app in each Play Store category plausibly needs. Categories Android reports as
/// unknown are never judged, so a missing category can't produce a false alarm.
const Map<String, Set<Capability>> expectedByCategory = {
  'game': {Capability.nearby},
  'audio': {Capability.microphone, Capability.media, Capability.nearby},
  'video': {Capability.camera, Capability.microphone, Capability.media},
  'image': {Capability.camera, Capability.media, Capability.location},
  'social': {Capability.camera, Capability.microphone, Capability.contacts, Capability.media, Capability.location, Capability.nearby},
  'news': {Capability.location},
  'maps': {Capability.location, Capability.backgroundLocation, Capability.nearby},
  'productivity': {Capability.calendar, Capability.contacts, Capability.camera, Capability.media, Capability.microphone},
};

const trustedInstallers = {
  'com.android.vending',
  'com.amazon.venezia',
  'com.sec.android.app.samsungapps',
  'com.huawei.appmarket',
  'org.fdroid.fdroid',
};

enum Severity { critical, high, medium }

class Finding {
  final Severity severity;
  final String text;
  const Finding(this.severity, this.text);
}

class AppAudit {
  final String package;
  final String label;
  final String category;
  final bool system;
  final String? installer;
  final Set<Capability> capabilities;
  final bool accessibility;
  final bool notificationListener;
  final bool deviceAdmin;
  final List<Finding> findings;
  final int risk;

  AppAudit._(this.package, this.label, this.category, this.system, this.installer, this.capabilities,
      this.accessibility, this.notificationListener, this.deviceAdmin, this.findings, this.risk);

  bool get sideloaded => !system && !trustedInstallers.contains(installer);
  bool get privileged => accessibility || notificationListener || deviceAdmin;

  factory AppAudit.fromMap(Map<dynamic, dynamic> m) {
    final granted = List<String>.from(m['granted'] as List? ?? const []);
    final caps = {for (final p in granted) if (permissionCapabilities[p] != null) permissionCapabilities[p]!};
    final category = m['category'] as String? ?? 'unknown';
    final system = m['system'] == true;
    final installer = m['installer'] as String?;
    final accessibility = m['accessibility'] == true;
    final listener = m['notificationListener'] == true;
    final admin = m['deviceAdmin'] == true;

    final findings = <Finding>[];
    var risk = caps.fold<int>(0, (sum, c) => sum + c.weight);
    if (listener) {
      findings.add(const Finding(Severity.critical, 'Reads every notification, including 2FA codes and message previews.'));
      risk += 30;
    }
    if (accessibility) {
      findings.add(const Finding(Severity.critical, 'Accessibility access: can read your screen and act on your behalf.'));
      risk += 30;
    }
    if (admin) {
      findings.add(const Finding(Severity.high, 'Device administrator: can lock or wipe the phone and resists uninstall.'));
      risk += 20;
    }
    if (caps.contains(Capability.backgroundLocation)) {
      findings.add(const Finding(Severity.high, 'Tracks location even when you are not using it.'));
    }
    final expected = expectedByCategory[category];
    if (expected != null) {
      final unexpected = caps.difference(expected).difference({Capability.media, Capability.nearby});
      for (final c in unexpected) {
        findings.add(Finding(Severity.medium, '${c.label} access is unusual for a $category app.'));
        risk += 10;
      }
    }
    final sideloaded = !system && !trustedInstallers.contains(installer);
    if (sideloaded && (caps.isNotEmpty || accessibility || listener || admin)) {
      findings.add(const Finding(Severity.medium, 'Installed from outside an app store.'));
      risk += 10;
    }

    return AppAudit._(m['package'] as String, m['label'] as String? ?? m['package'] as String, category, system,
        installer, caps, accessibility, listener, admin, findings, risk.clamp(0, 100));
  }
}

class PostureCheck {
  final String title;
  final String detail;
  final bool ok;
  final Severity severity;
  final String settingsScreen;
  const PostureCheck(this.title, this.detail, this.ok, this.severity, this.settingsScreen);
}

class DevicePosture {
  final String device;
  final String android;
  final List<PostureCheck> checks;
  const DevicePosture(this.device, this.android, this.checks);

  factory DevicePosture.fromMap(Map<dynamic, dynamic> m, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final patch = DateTime.tryParse(m['securityPatch'] as String? ?? '');
    final patchAge = patch == null ? null : today.difference(patch).inDays;
    return DevicePosture(
      '${m['manufacturer'] ?? ''} ${m['model'] ?? ''}'.trim(),
      'Android ${m['release'] ?? '?'} (API ${m['sdkInt'] ?? '?'})',
      [
        PostureCheck('Screen lock', m['screenLock'] == true ? 'A PIN, pattern or password protects this phone.' : 'Anyone who picks up this phone can open it.',
            m['screenLock'] == true, Severity.critical, 'security'),
        PostureCheck(
          'Security patch',
          patch == null ? 'Patch level unavailable.' : 'Last patch ${m['securityPatch']}, $patchAge days ago.',
          patchAge != null && patchAge <= 90,
          Severity.high,
          'security',
        ),
        PostureCheck('Storage encryption', m['encrypted'] == true ? 'Data on this phone is encrypted.' : 'Data on this phone is not encrypted.',
            m['encrypted'] == true, Severity.high, 'security'),
        PostureCheck('USB debugging', m['usbDebugging'] == true ? 'A connected computer can install apps and read data.' : 'Off.',
            m['usbDebugging'] != true, Severity.high, 'developer'),
        PostureCheck('Developer options', m['developerOptions'] == true ? 'Enabled. Turn off unless you need them.' : 'Off.',
            m['developerOptions'] != true, Severity.medium, 'developer'),
      ],
    );
  }
}

class DeviceAuditService {
  static const channel = MethodChannel('privacyshield/device');

  bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<List<AppAudit>> scanApps() async {
    final raw = await channel.invokeListMethod<Map<dynamic, dynamic>>('scanApps') ?? const [];
    final apps = raw.map(AppAudit.fromMap).toList()..sort((a, b) => b.risk.compareTo(a.risk));
    return apps;
  }

  Future<DevicePosture> posture() async =>
      DevicePosture.fromMap(await channel.invokeMapMethod<dynamic, dynamic>('devicePosture') ?? const {});

  Future<void> openAppSettings(String package) => channel.invokeMethod('openAppSettings', {'package': package});

  Future<void> openSettings(String screen) => channel.invokeMethod('openSettings', {'screen': screen});
}
