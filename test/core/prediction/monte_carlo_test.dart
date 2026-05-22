import 'package:flutter_test/flutter_test.dart';
import 'package:aiko/core/prediction/monte_carlo_engine.dart';

void main() {
  group('Monte Carlo Engine Tests', () {
    const engine = MonteCarloEngine();

    test('Zero months to target returns 100% if already achieved', () {
      final result = engine.run(
        currentBalance: 5000.0,
        monthlyContribution: 200.0,
        targetAmount: 4000.0,
        targetMonths: 0,
      );

      expect(result.successProbabilityPercent, 100.0);
      expect(result.expectedValue, 5000.0);
      expect(result.conservativeValue, 5000.0);
      expect(result.optimisticValue, 5000.0);
    });

    test('Zero months to target returns 0% if not achieved', () {
      final result = engine.run(
        currentBalance: 3000.0,
        monthlyContribution: 200.0,
        targetAmount: 4000.0,
        targetMonths: 0,
      );

      expect(result.successProbabilityPercent, 0.0);
    });

    test('Standard simulation computes logical distribution bounds', () {
      final result = engine.run(
        currentBalance: 1000.0,
        monthlyContribution: 100.0,
        targetAmount: 2500.0,
        targetMonths: 12,
        expectedAnnualReturnPercent: 8.0,
        annualVolatilityPercent: 12.0,
        iterations: 500,
      );

      // Expected value should be higher than conservative, and optimistic higher than expected
      expect(result.conservativeValue, lessThan(result.expectedValue));
      expect(result.expectedValue, lessThan(result.optimisticValue));
      
      // Since 1000 + 1200 = 2200 is less than 2500 target, probability should be in a normal range
      expect(result.successProbabilityPercent, greaterThanOrEqualTo(0.0));
      expect(result.successProbabilityPercent, lessThanOrEqualTo(100.0));
    });
  });
}
