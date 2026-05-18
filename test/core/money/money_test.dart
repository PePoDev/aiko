import 'package:aiko/core/money/money.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses, adds, subtracts, and formats same-currency money', () {
    final a = Money.parse('10.25', 'USD');
    final b = Money.parse('2.75', 'USD');

    expect((a + b).amount, Decimal.parse('13.00'));
    expect((a - b).amount, Decimal.parse('7.50'));
    expect(a.format(), contains('10.25'));
  });

  test('rejects cross-currency arithmetic', () {
    expect(
      () => Money.parse('1', 'USD') + Money.parse('1', 'EUR'),
      throwsArgumentError,
    );
  });
}
