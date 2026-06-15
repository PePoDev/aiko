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
      expect(result.expectedAmount, 5000.0);
      expect(result.conservativeAmount, 5000.0);
      expect(result.optimisticAmount, 5000.0);
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

    test('Returns NaN-safe bounds across many runs', () {
      // Run a long-horizon simulation and assert the bounds stay finite
      // and ordered. The earlier "logical distribution bounds" test only
      // checked `>= 0 && <= 100`, which never failed.
      final result = engine.run(
        currentBalance: 1000.0,
        monthlyContribution: 100.0,
        targetAmount: 2500.0,
        targetMonths: 60,
        expectedAnnualReturnPercent: 8.0,
        annualVolatilityPercent: 12.0,
        iterations: 1000,
      );

      expect(result.conservativeAmount.isFinite, isTrue);
      expect(result.expectedAmount.isFinite, isTrue);
      expect(result.optimisticAmount.isFinite, isTrue);
      expect(
        result.conservativeAmount,
        lessThanOrEqualTo(result.expectedAmount),
      );
      expect(result.expectedAmount, lessThanOrEqualTo(result.optimisticAmount));
      expect(result.successProbabilityPercent, inInclusiveRange(0.0, 100.0));
    });
  });
}
