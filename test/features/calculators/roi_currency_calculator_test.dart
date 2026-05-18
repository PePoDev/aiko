import 'package:aiko/features/calculators/application/calculator_services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ROI and currency conversion calculate deterministic results', () {
    const service = CalculatorServices();

    expect(service.roi(initialInvestment: 100, endingValue: 125), 0.25);
    expect(service.convertCurrency(sourceAmount: 100, exchangeRate: 1.2), 120);
  });
}
