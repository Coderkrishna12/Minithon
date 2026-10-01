import 'package:flutter_test/flutter_test.dart';
import 'package:privacyshield_mobile/services/password_csv_import.dart';

void main() {
  test('processes password reuse locally and returns only labels', () {
    const csv = 'name,url,username,password\n'
        'Alpha,https://alpha.example,person,private-secret\n'
        'Beta,https://beta.example,person,private-secret\n'
        'Gamma,https://gamma.example,person,unique-secret';
    final result = parsePasswordManagerCsv(csv);
    expect(result, hasLength(3));
    expect(result[0].passwordGroup, 'reuse_1');
    expect(result[1].passwordGroup, 'reuse_1');
    expect(result[2].passwordGroup, isNull);
    final request = result.map((entry) => entry.toApiJson()).toList().toString();
    expect(request, isNot(contains('private-secret')));
    expect(request, isNot(contains('unique-secret')));
    expect(request, contains('reuse_1'));
  });

  test('handles quoted commas and does not duplicate the same service', () {
    const csv = 'service,password\n"Example, Inc",one\n"Example, Inc",two\nOther,three';
    final result = parsePasswordManagerCsv(csv);
    expect(result.map((e) => e.serviceName), ['Example, Inc', 'Other']);
    expect(result.every((e) => e.passwordGroup == null), isTrue);
  });
}
