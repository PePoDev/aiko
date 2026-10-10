import 'package:aiko/features/accounts/presentation/account_form/account_amount_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String? parse(String input) => parseAccountAmountInput(input)?.toString();

  test('accepts thousands separators', () {
    expect(parse('50,000'), '50000');
    expect(parse('1,234.50'), '1234.5');
    expect(parse('-1,000'), '-1000');
    expect(parse('12,345,678'), '12345678');
  });

  test('trims and accepts plain numbers', () {
    expect(parse(' 42 '), '42');
    expect(parse('0.75'), '0.75');
    expect(parse('+15'), '15');
  });

  test('empty or ambiguous input is not a number', () {
    expect(parse(''), isNull);
    expect(parse('   '), isNull);
    expect(parse('12,50'), isNull, reason: 'not a thousands grouping');
    expect(parse('1,00,000'), isNull);
    expect(parse('abc'), isNull);
  });
}
