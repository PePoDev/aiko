import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/debt_loans/application/debt_payoff_service.dart';
import 'package:aiko/features/debt_loans/domain/debt_loan_plan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('credit card and debt payoff comparison flow', (tester) async {
    final ranked = const DebtPayoffService().rank([
      DebtLoanPlan(
        name: 'Loan',
        balance: Money.parse('1000', 'USD'),
        interestRatePercent: 4,
        monthlyPayment: Money.parse('100', 'USD'),
      ),
      DebtLoanPlan(
        name: 'Card',
        balance: Money.parse('500', 'USD'),
        interestRatePercent: 22,
        monthlyPayment: Money.parse('100', 'USD'),
      ),
    ], DebtPayoffStrategy.avalanche);

    expect(ranked.first.name, 'Card');
  });
}
