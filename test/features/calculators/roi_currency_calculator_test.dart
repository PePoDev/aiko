import 'package:aiko/features/calculators/application/calculator_services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ROI and currency conversion calculate deterministic results', () {
    expect(
      CalculatorServices.roi(initialInvestment: 100, endingValue: 125),
      0.25,
    );
    expect(
      CalculatorServices.convertCurrency(sourceAmount: 100, exchangeRate: 1.2),
      120,
    );
  });
}
