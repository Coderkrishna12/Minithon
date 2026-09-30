import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:privacyshield_mobile/screens/leak_check_screen.dart';

const _sample = 'sample';
final _sampleHash = sha1.convert(utf8.encode(_sample)).toString().toUpperCase();

String _rangeBody() => [
      '${'0' * 35}:3',
      '${_sampleHash.substring(5)}:9545824',
      '${'F' * 35}:2',
    ].join('\r\n');

MockClient _mock(List<Uri> seen, {int status = 200}) => MockClient((req) async {
      seen.add(req.url);
      return http.Response(status == 200 ? _rangeBody() : '', status);
    });

void main() {
  test('sends only the 5-char hash prefix and finds the leak count', () async {
    final seen = <Uri>[];
    final result = await http.runWithClient(() => checkPasswordLeak(_sample), () => _mock(seen));
    expect(seen.single.toString(), 'https://api.pwnedpasswords.com/range/${_sampleHash.substring(0, 5)}');
    expect(result.count, 9545824);
    expect(result.candidates, 3);
  });

  test('reports zero when the suffix is not in the range', () async {
    final result = await http.runWithClient(
      () => checkPasswordLeak('aB3!' * 7),
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
      await tester.enterText(find.byType(TextField), _sample);
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
      await tester.enterText(find.byType(TextField), _sample);
      await tester.pump();
      await tester.tap(find.text('Check leaks'));
      await tester.pumpAndSettle();
    }, () => _mock([], status: 503));

    expect(find.textContaining("Couldn't reach the breach database"), findsOneWidget);
  });
}
