import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/debt_loans/application/debt_payoff_service.dart';
import 'package:aiko/features/debt_loans/domain/debt_loan_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ranks avalanche by highest interest and estimates payoff months', () {
    final debts = [
      DebtLoanPlan(
        name: 'Small',
        balance: Money.parse('600', 'USD'),
        interestRatePercent: 5,
        monthlyPayment: Money.parse('100', 'USD'),
      ),
      DebtLoanPlan(
        name: 'High APR',
        balance: Money.parse('1200', 'USD'),
        interestRatePercent: 18,
        monthlyPayment: Money.parse('100', 'USD'),
      ),
    ];

    final ranked = const DebtPayoffService().rank(
      debts,
      DebtPayoffStrategy.avalanche,
    );

    expect(ranked.first.name, 'High APR');
    expect(ranked.first.monthsToPayoff, 12);
  });
}
