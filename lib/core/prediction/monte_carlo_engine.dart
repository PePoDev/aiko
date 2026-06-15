import 'dart:math';

class MonteCarloSimulationResult {
  const MonteCarloSimulationResult({
    required this.successProbabilityPercent,
    required this.optimisticAmount,
    required this.expectedAmount,
    required this.conservativeAmount,
  });

  final double successProbabilityPercent;
  final double optimisticAmount;
  final double expectedAmount;
  final double conservativeAmount;
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
  }) {
    if (targetMonths <= 0) {
      final success = currentBalance >= targetAmount;
      return MonteCarloSimulationResult(
        successProbabilityPercent: success ? 100.0 : 0.0,
        optimisticAmount: currentBalance,
        expectedAmount: currentBalance,
        conservativeAmount: currentBalance,
      );
    }

    final random = Random();
    final double monthlyRate = expectedAnnualReturnPercent / 12 / 100;
    final double monthlyVol = annualVolatilityPercent / sqrt(12) / 100;

    final List<double> finalBalances = [];
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
      finalBalances.add(bal);
      if (bal >= targetAmount) {
        successCount++;
      }
    }

    // Sort to extract percentiles
    finalBalances.sort();

    final int idx10 = (iterations * 0.10).floor().clamp(0, iterations - 1);
    final int idx50 = (iterations * 0.50).floor().clamp(0, iterations - 1);
    final int idx90 = (iterations * 0.90).floor().clamp(0, iterations - 1);

    return MonteCarloSimulationResult(
      successProbabilityPercent: (successCount / iterations) * 100,
      conservativeAmount: finalBalances[idx10],
      expectedAmount: finalBalances[idx50],
      optimisticAmount: finalBalances[idx90],
    );
  }
}
