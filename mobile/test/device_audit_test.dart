import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:privacyshield_mobile/screens/device_audit_screen.dart';
import 'package:privacyshield_mobile/services/device_audit.dart';

const _p = 'android.permission.';

Map<String, dynamic> _app(String label, String category, List<String> granted,
        {String installer = 'com.android.vending', bool system = false, bool listener = false}) =>
    {
      'package': 'com.example.${label.toLowerCase()}',
      'label': label,
      'category': category,
      'system': system,
      'installer': installer,
      'granted': granted.map((g) => '$_p$g').toList(),
      'accessibility': false,
      'notificationListener': listener,
      'deviceAdmin': false,
    };

final _apps = [
  _app('Puzzle', 'game', ['RECORD_AUDIO', 'ACCESS_FINE_LOCATION']),
  _app('Chat', 'social', ['RECORD_AUDIO', 'CAMERA', 'READ_CONTACTS']),
  _app('Cleaner', 'unknown', ['READ_SMS'], installer: 'com.google.android.packageinstaller', listener: true),
  _app('Dialer', 'unknown', ['RECORD_AUDIO', 'READ_CALL_LOG'], system: true),
];

const _posture = {
  'manufacturer': 'Pixel',
  'model': '8',
  'release': '15',
  'sdkInt': 35,
  'securityPatch': '2026-01-05',
  'screenLock': true,
  'developerOptions': true,
  'usbDebugging': false,
  'encrypted': true,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppAudit', () {
    test('flags permissions that do not fit the app category', () {
      final game = AppAudit.fromMap(_apps[0]);
      expect(game.capabilities, {Capability.microphone, Capability.location});
      expect(game.findings.map((f) => f.text), contains('Microphone access is unusual for a game app.'));
    });

    test('expected permissions for the category are not flagged', () {
      expect(AppAudit.fromMap(_apps[1]).findings, isEmpty);
    });

    test('unknown category is never judged, but privileged access and sideloading are', () {
      final cleaner = AppAudit.fromMap(_apps[2]);
      expect(cleaner.findings.where((f) => f.text.contains('unusual')), isEmpty);
      expect(cleaner.findings.first.severity, Severity.critical);
      expect(cleaner.sideloaded, isTrue);
      expect(cleaner.risk, greaterThan(AppAudit.fromMap(_apps[1]).risk));
    });

    test('posture flags stale patches and developer options', () {
      final posture = DevicePosture.fromMap(_posture, now: DateTime(2026, 9, 30));
      final failing = posture.checks.where((c) => !c.ok).map((c) => c.title);
      expect(failing, containsAll(['Security patch', 'Developer options']));
      expect(failing, isNot(contains('Screen lock')));
    });
  });

  testWidgets('screen leads with the worst real finding and counts only user apps', (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(DeviceAuditService.channel, (call) async {
      calls.add(call.method);
      return switch (call.method) {
        'scanApps' => _apps,
        'devicePosture' => _posture,
        _ => true,
      };
    });

    await tester.pumpWidget(const MaterialApp(home: DeviceAuditScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('1 app can', findRichText: true), findsOneWidget);
    expect(find.textContaining('read every notification', findRichText: true), findsOneWidget);
    expect(find.text('3 apps checked on Pixel 8 · Android 15 (API 35)'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Privileged access'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Cleaner'), findsWidgets);
    expect(find.text('Dialer'), findsNothing);

    await tester.scrollUntilVisible(find.text('Puzzle'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Puzzle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revoke in Android settings'));
    await tester.pumpAndSettle();
    expect(calls, contains('openAppSettings'));
  });
}
