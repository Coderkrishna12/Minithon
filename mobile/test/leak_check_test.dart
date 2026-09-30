import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:privacyshield_mobile/screens/leak_check_screen.dart';

// SHA-1("password") = 5BAA61E4C9B93F3F0682250B6CF8331B7EE68FD8
const _passwordRange = '003D68EB55068C33ACE09247EE4C639306B:3\r\n'
    '1E4C9B93F3F0682250B6CF8331B7EE68FD8:9545824\r\n'
    '1E4F5B4A8AD5A1A18F5A3CBD5F3A6B2AB4E:2';

MockClient _mock(List<Uri> seen, {int status = 200}) => MockClient((req) async {
      seen.add(req.url);
      return http.Response(status == 200 ? _passwordRange : '', status);
    });

void main() {
  test('sends only the 5-char hash prefix and finds the leak count', () async {
    final seen = <Uri>[];
    final result = await http.runWithClient(() => checkPasswordLeak('password'), () => _mock(seen));
    expect(seen.single.toString(), 'https://api.pwnedpasswords.com/range/5BAA6');
    expect(result.count, 9545824);
    expect(result.candidates, 3);
  });

  test('reports zero when the suffix is not in the range', () async {
    final result = await http.runWithClient(
      () => checkPasswordLeak('Tr0ub4dor&3-horse-battery!'),
      () => _mock([]),
    );
    expect(result.count, 0);
    expect(result.crackTime, 'millions of years');
  });

  test('crack time estimate is instant for tiny passwords', () {
    expect(estimateCrackTime('abc'), 'instantly');
  });

  testWidgets('shows the animated leak count', (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: LeakCheckScreen()));
      await tester.enterText(find.byType(TextField), 'password');
      await tester.pump();
      await tester.tap(find.text('Check leaks'));
      await tester.pumpAndSettle();
    }, () => _mock([]));

    expect(find.text('9,545,824'), findsOneWidget);
    expect(find.text('EXTREMELY COMMON'), findsOneWidget);
    expect(find.textContaining('only the first 5 characters', findRichText: true), findsOneWidget);
  });

  testWidgets('shows an error when the API is unreachable', (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: LeakCheckScreen()));
      await tester.enterText(find.byType(TextField), 'password');
      await tester.pump();
      await tester.tap(find.text('Check leaks'));
      await tester.pumpAndSettle();
    }, () => _mock([], status: 503));

    expect(find.textContaining("Couldn't reach the breach database"), findsOneWidget);
  });
}
