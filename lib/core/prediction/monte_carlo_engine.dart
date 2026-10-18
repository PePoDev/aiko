import 'dart:math';

class MonteCarloSimulationResult {
  const MonteCarloSimulationResult({required this.successProbabilityPercent});

  final double successProbabilityPercent;
}

class MonteCarloEngine {
  const MonteCarloEngine();

  MonteCarloSimulationResult run({
    required double currentBalance,
    required double monthlyContribution,
    required double targetAmount,
    required int targetMonths,
    double expectedAnnualReturnPercent = 5.0,
    double annualVolatilityPercent = 10.0,
    int iterations = 1000,
    int seed = 42,
  }) {
    if (targetMonths <= 0) {
      final success = currentBalance >= targetAmount;
      return MonteCarloSimulationResult(
        successProbabilityPercent: success ? 100.0 : 0.0,
      );
    }

    // Seeded: the same inputs always give the same odds, so the figure
    // doesn't change each time the screen reloads.
    final random = Random(seed);
    final double monthlyRate = expectedAnnualReturnPercent / 12 / 100;
    final double monthlyVol = annualVolatilityPercent / sqrt(12) / 100;

    int successCount = 0;

    for (int i = 0; i < iterations; i++) {
      double bal = currentBalance;
      for (int m = 0; m < targetMonths; m++) {
        // Box-Muller transform to get standard normal random variable
        double u1 = random.nextDouble();
        final double u2 = random.nextDouble();
        if (u1 < 1e-9) u1 = 1e-9;

        final double z = sqrt(-2.0 * log(u1)) * cos(2.0 * pi * u2);
        final double monthlyReturn = monthlyRate + z * monthlyVol;

        bal = bal * (1.0 + monthlyReturn) + monthlyContribution;
      }
      if (bal >= targetAmount) {
        successCount++;
      }
    }

    return MonteCarloSimulationResult(
      successProbabilityPercent: (successCount / iterations) * 100,
    );
  }
}
