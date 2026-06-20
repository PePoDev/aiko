import 'package:aiko/features/accounts/domain/account_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('carries field name and message', () {
    const ex = AccountValidationException('creditLimit', 'Limit required.');
    expect(ex.field, 'creditLimit');
    expect(ex.message, 'Limit required.');
    expect(ex.toString(), contains('creditLimit'));
  });
}
