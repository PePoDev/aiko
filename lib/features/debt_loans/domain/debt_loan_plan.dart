import '../../../core/money/money.dart';

enum DebtPayoffStrategy { snowball, avalanche, custom }

class DebtLoanPlan {
  const DebtLoanPlan({
    required this.name,
    required this.balance,
    required this.interestRatePercent,
    required this.monthlyPayment,
    this.strategy = DebtPayoffStrategy.avalanche,
  });

  final String name;
  final Money balance;
  final double interestRatePercent;
  final Money monthlyPayment;
  final DebtPayoffStrategy strategy;

  int get monthsToPayoff {
    if (monthlyPayment.amount.toDouble() <= 0) {
      return 0;
    }

    return (balance.amount.toDouble() / monthlyPayment.amount.toDouble())
        .ceil();
  }
}
