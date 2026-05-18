import 'package:aiko/features/calculators/application/calculator_services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compound interest grows with contributions', () {
    final value = const CalculatorServices().compoundInterest(
      principal: 1000,
      monthlyContribution: 100,
      annualRate: 0.06,
      years: 1,
    );

    expect(value, greaterThan(2200));
  });
}
