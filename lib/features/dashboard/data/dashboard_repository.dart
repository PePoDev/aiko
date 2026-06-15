import 'package:decimal/decimal.dart';

import '../../../core/money/money.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/domain/account.dart';
import '../../categories/data/category_repository.dart';
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
    final categories = (await const CategoryRepository().list())
        .where(
          (category) =>
              category.monthlyLimit != null &&
              category.monthlyLimit!.amount > Decimal.zero,
        )
        .toList(growable: false);

    final currency = _firstCurrency(accounts, transactions, categories);
    var netWorth = Decimal.zero;
    var totalCash = Decimal.zero;
    for (final account in accounts) {
      // Goal accounts represent savings targets, not free cash; skip them
      // when summing cash and liquid assets.
      if (account.type == AccountType.goal) continue;
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
    for (final category in categories) {
      totalBudget += category.monthlyLimit!.amount;
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
    final type = switch (row['widget_key'] as String? ?? '') {
      'summary' => DashboardWidgetType.aikoWelcome,
      'pace' => DashboardWidgetType.dailySpending,
      'analytics' => DashboardWidgetType.dailySummary,
      'due_items' => DashboardWidgetType.dueItems,
      'this_month_overview' => DashboardWidgetType.thisMonthOverview,
      'daily_spending' => DashboardWidgetType.dailySpending,
      'safe_this_week' => DashboardWidgetType.safeThisWeek,
      'daily_summary' => DashboardWidgetType.dailySummary,
      'net_earnings' => DashboardWidgetType.netEarnings,
      'category_budgets' => DashboardWidgetType.categoryBudgets,
      'spending_calendar' => DashboardWidgetType.spendingCalendar,
      'cash_flow_mapping' => DashboardWidgetType.cashFlowMapping,
      'aiko_goal_simulator' => DashboardWidgetType.aikoGoalSimulator,
      _ => DashboardWidgetType.aikoWelcome,
    };

    return DashboardWidgetPreference(
      type: type,
      isVisible: row['is_visible'] as bool? ?? true,
      position: row['position'] as int? ?? 0,
    );
  }

  static String _firstCurrency(
    Iterable<Account> accounts,
    Iterable<FinanceTransaction> transactions,
    Iterable<Object> categories,
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
    return 'USD';
  }

  static List<DashboardWidgetPreference> _defaultPreferences() {
    return DashboardWidgetPreference.defaultLayout;
  }
}
