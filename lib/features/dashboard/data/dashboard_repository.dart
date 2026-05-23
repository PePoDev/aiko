import 'package:decimal/decimal.dart';

import '../../../core/money/money.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/domain/account.dart';
import '../../budgets/data/budget_repository.dart';
import '../../budgets/domain/budget.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../transactions/domain/transaction.dart';
import '../domain/dashboard_summary.dart';
import '../domain/dashboard_widget_preference.dart';

class DashboardRepository {
  const DashboardRepository();

  Future<DashboardSummary> loadSummary() async {
    final now = DateTime.now();
    final periodStart = DateTime(now.year, now.month);
    final periodEnd = DateTime(now.year, now.month + 1, 0);

    final accounts = (await const AccountRepository().list())
        .where((account) => account.isActive)
        .toList(growable: false);
    final transactions = (await const TransactionRepository().list())
        .where(
          (transaction) =>
              !transaction.date.isBefore(periodStart) &&
              !transaction.date.isAfter(periodEnd),
        )
        .toList(growable: false);
    final budgets = (await const BudgetRepository().list())
        .where(
          (budget) =>
              budget.status.name == 'active' &&
              !budget.periodStart.isAfter(periodEnd) &&
              !budget.periodEnd.isBefore(periodStart),
        )
        .toList(growable: false);

    final currency = _firstCurrency(accounts, transactions, budgets);
    var netWorth = Decimal.zero;
    var totalCash = Decimal.zero;
    for (final account in accounts) {
      final amount = account.currentBalance.amount;
      if (account.includeInNetWorth) {
        netWorth += amount;
      }
      if (account.type.name == 'cash' || account.type.name == 'bank') {
        totalCash += amount;
      }
    }

    var monthlyIncome = Decimal.zero;
    var monthlySpending = Decimal.zero;
    for (final transaction in transactions) {
      final amount = transaction.amount.amount;
      if (transaction.type.name == 'income') {
        monthlyIncome += amount;
      } else if (transaction.type.name == 'expense') {
        monthlySpending += amount;
      }
    }

    var totalBudget = Decimal.zero;
    for (final budget in budgets) {
      totalBudget += budget.amount.amount;
    }

    final weeklyFlow =
        ((monthlyIncome - monthlySpending) / Decimal.parse('4.33')).toDecimal(
          scaleOnInfinitePrecision: 2,
        );
    final safeToSpend = weeklyFlow > Decimal.zero ? weeklyFlow : Decimal.zero;
    final percentOfBudgetUsed = totalBudget > Decimal.zero
        ? monthlySpending.toDouble() / totalBudget.toDouble() * 100
        : 0.0;
    final daysElapsedRatio = now.day / periodEnd.day;

    return DashboardSummary(
      netWorth: Money(amount: netWorth, currency: currency),
      totalCash: Money(amount: totalCash, currency: currency),
      monthlyIncome: Money(amount: monthlyIncome, currency: currency),
      monthlySpending: Money(amount: monthlySpending, currency: currency),
      safeToSpend: Money(amount: safeToSpend, currency: currency),
      paceStatus: PaceStatus(
        percentOfBudgetUsed: percentOfBudgetUsed,
        daysElapsedRatio: daysElapsedRatio,
      ),
    );
  }

  Future<List<DashboardWidgetPreference>> loadPreferences() async {
    final session = AikoSupabase.tryClient()?.auth.currentUser;
    final client = AikoSupabase.tryClient();
    if (client == null || session == null) {
      return _defaultPreferences();
    }

    try {
      final response = await client
          .from('dashboard_widget_preferences')
          .select()
          .eq('user_id', session.id)
          .eq('dashboard_mode', 'personal')
          .order('position');

      return response
          .map((row) => _preferenceFromRow(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    } catch (_) {
      return _defaultPreferences();
    }
  }

  static DashboardWidgetPreference _preferenceFromRow(
    Map<String, dynamic> row,
  ) {
    final size = DashboardWidgetSize.values.firstWhere(
      (item) => item.name == (row['size'] as String? ?? 'compact'),
      orElse: () => DashboardWidgetSize.compact,
    );

    return DashboardWidgetPreference(
      widgetKey: row['widget_key'] as String,
      isVisible: row['is_visible'] as bool? ?? true,
      position: row['position'] as int? ?? 0,
      size: size,
    );
  }

  static String _firstCurrency(
    Iterable<Account> accounts,
    Iterable<FinanceTransaction> transactions,
    Iterable<Budget> budgets,
  ) {
    for (final account in accounts) {
      if (account.currentBalance.currency.isNotEmpty) {
        return account.currentBalance.currency;
      }
    }
    for (final transaction in transactions) {
      if (transaction.amount.currency.isNotEmpty) {
        return transaction.amount.currency;
      }
    }
    for (final budget in budgets) {
      if (budget.amount.currency.isNotEmpty) {
        return budget.amount.currency;
      }
    }
    return 'USD';
  }

  static List<DashboardWidgetPreference> _defaultPreferences() {
    return const [
      DashboardWidgetPreference(
        widgetKey: 'summary',
        isVisible: true,
        position: 0,
        size: DashboardWidgetSize.expanded,
      ),
      DashboardWidgetPreference(
        widgetKey: 'pace',
        isVisible: true,
        position: 1,
        size: DashboardWidgetSize.compact,
      ),
      DashboardWidgetPreference(
        widgetKey: 'goals',
        isVisible: true,
        position: 2,
        size: DashboardWidgetSize.compact,
      ),
    ];
  }
}
