import 'package:flutter_test/flutter_test.dart';
import 'package:privacyshield_mobile/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const PrivacyShieldApp());
    expect(find.text('PrivacyShield'), findsOneWidget);
  });
}
