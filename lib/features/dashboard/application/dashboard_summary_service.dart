import '../../../core/money/money.dart';
import '../../accounts/domain/account.dart';
import '../../transactions/domain/transaction.dart';
import '../domain/dashboard_summary.dart';

class DashboardSummaryService {
  const DashboardSummaryService();

  Money totalCash(List<Account> accounts, String currency) {
    return accounts
        .where(
          (account) =>
              account.includeInNetWorth && account.currency == currency,
        )
        .fold(
          Money.zero(currency),
          (total, account) => total + account.currentBalance,
        );
  }

  Money spending(List<FinanceTransaction> transactions, String currency) {
    return transactions
        .where((transaction) => transaction.type == TransactionType.expense)
        .fold(
          Money.zero(currency),
          (total, transaction) => total + transaction.amount,
        );
  }

  Money leftover({
    required Money income,
    required Money fixedBills,
    required Money requiredExpenses,
    required Money debtPayments,
    required Money goalContributions,
    required Money currentSpending,
  }) {
    return income -
        fixedBills -
        requiredExpenses -
        debtPayments -
        goalContributions -
        currentSpending;
  }

  PaceStatus pace(Money spending, Money budget, double daysElapsedRatio) {
    final percent = spending.amount.toDouble() / budget.amount.toDouble() * 100;
    return PaceStatus(
      percentOfBudgetUsed: percent,
      daysElapsedRatio: daysElapsedRatio,
    );
  }
}
