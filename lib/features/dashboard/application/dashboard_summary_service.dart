import '../../../core/money/money.dart';
import '../../../core/money/currency_conversion_service.dart';
import '../../accounts/domain/account.dart';
import '../../transactions/domain/transaction.dart';
import '../domain/dashboard_summary.dart';

class DashboardSummaryService {
  const DashboardSummaryService();

  Money totalCash(
    List<Account> accounts,
    String currency, {
    CurrencyConversionService? converter,
  }) {
    return accounts
        .where((account) => account.includeInNetWorth)
        .map((account) {
          if (account.currency == currency) {
            return account.currentBalance;
          }
          return converter?.convert(account.currentBalance, currency);
        })
        .whereType<Money>()
        .fold(Money.zero(currency), (total, balance) => total + balance);
  }

  Money spending(
    List<FinanceTransaction> transactions,
    String currency, {
    CurrencyConversionService? converter,
  }) {
    return transactions
        .where((transaction) => transaction.type == TransactionType.expense)
        .map((transaction) {
          if (transaction.amount.currency == currency) {
            return transaction.amount;
          }
          return converter?.convert(transaction.amount, currency);
        })
        .whereType<Money>()
        .fold(Money.zero(currency), (total, amount) => total + amount);
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
