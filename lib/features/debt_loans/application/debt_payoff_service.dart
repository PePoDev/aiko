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
}
