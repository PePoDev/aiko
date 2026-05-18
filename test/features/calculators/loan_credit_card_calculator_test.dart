import 'package:aiko/features/calculators/application/calculator_services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loan payment handles zero and positive rates', () {
    final zeroRate = const CalculatorServices().loanPayment(
      principal: 1200,
      annualRate: 0,
      months: 12,
    );
    final positiveRate = const CalculatorServices().loanPayment(
      principal: 1200,
      annualRate: 0.12,
      months: 12,
    );

    expect(zeroRate, 100);
    expect(positiveRate, greaterThan(100));
  });
}
