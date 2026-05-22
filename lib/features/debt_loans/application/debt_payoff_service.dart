import '../domain/debt_loan_plan.dart';

class DebtPayoffService {
  const DebtPayoffService();

  List<DebtLoanPlan> rank(
    List<DebtLoanPlan> debts,
    DebtPayoffStrategy strategy,
  ) {
    final sorted = [...debts];
    switch (strategy) {
      case DebtPayoffStrategy.snowball:
        sorted.sort((a, b) => a.balance.compareTo(b.balance));
      case DebtPayoffStrategy.avalanche:
        sorted.sort(
          (a, b) => b.interestRatePercent.compareTo(a.interestRatePercent),
        );
      case DebtPayoffStrategy.custom:
        break;
    }
    return sorted;
  }

  Map<String, dynamic> simulatePayoff({
    required List<DebtLoanPlan> debts,
    required DebtPayoffStrategy strategy,
    required double extraPayment,
  }) {
    if (debts.isEmpty) {
      return {'months': 0, 'interest': 0.0, 'never': false};
    }

    final ranked = rank(debts, strategy);
    final List<double> balances = ranked.map((d) => d.balance.amount.toDouble()).toList();
    final List<double> rates = ranked.map((d) => d.interestRatePercent / 100 / 12).toList();
    final List<double> mins = ranked.map((d) => d.monthlyPayment.amount.toDouble()).toList();

    double totalInterest = 0.0;
    int months = 0;
    
    final totalMins = mins.fold(0.0, (sum, val) => sum + val);
    final totalBudget = totalMins + extraPayment;

    while (balances.any((b) => b > 0) && months < 360) {
      months++;
      double pool = totalBudget;

      // 1. Accrue interest and pay minimums
      for (int i = 0; i < balances.length; i++) {
        if (balances[i] <= 0) continue;
        final interest = balances[i] * rates[i];
        totalInterest += interest;
        balances[i] += interest;

        final paid = balances[i] < mins[i] ? balances[i] : mins[i];
        balances[i] -= paid;
        pool -= paid;
      }

      // 2. Distribute remaining extra payments to highest priority debts first
      if (pool > 0) {
        for (int i = 0; i < balances.length; i++) {
          if (balances[i] <= 0) continue;
          final extra = balances[i] < pool ? balances[i] : pool;
          balances[i] -= extra;
          pool -= extra;
          if (pool <= 0) break;
        }
      }
    }

    final never = months >= 360 && balances.any((b) => b > 0);
    return {
      'months': never ? 999 : months,
      'interest': totalInterest,
      'never': never,
    };
  }
}
