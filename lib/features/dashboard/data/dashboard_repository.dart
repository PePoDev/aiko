import 'package:decimal/decimal.dart';

import '../../../core/money/money.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/dashboard_summary.dart';
import '../domain/dashboard_widget_preference.dart';

class DashboardRepository {
  const DashboardRepository();

  Future<DashboardSummary> loadSummary() async {
    final session = AikoSupabase.requireSession();
    final now = DateTime.now();
    final periodStart = DateTime(now.year, now.month);
    final periodEnd = DateTime(now.year, now.month + 1, 0);

    final accounts = await session.client
        .from('accounts')
        .select('current_balance,currency,include_in_net_worth,type')
        .eq('user_id', session.userId)
        .eq('is_active', true);
    final transactions = await session.client
        .from('transactions')
        .select('type,amount,currency,date')
        .eq('user_id', session.userId)
        .gte('date', periodStart.toIso8601String().substring(0, 10))
        .lte('date', periodEnd.toIso8601String().substring(0, 10));
    final budgets = await session.client
        .from('budgets')
        .select('amount,currency')
        .eq('user_id', session.userId)
        .eq('status', 'active')
        .lte('period_start', periodEnd.toIso8601String().substring(0, 10))
        .gte('period_end', periodStart.toIso8601String().substring(0, 10));

    final currency = _firstCurrency(accounts, transactions, budgets);
    var netWorth = Decimal.zero;
    var totalCash = Decimal.zero;
    for (final row in accounts) {
      final amount = Decimal.parse('${row['current_balance'] ?? 0}');
      if (row['include_in_net_worth'] as bool? ?? true) {
        netWorth += amount;
      }
      if (row['type'] == 'cash' || row['type'] == 'bank') {
        totalCash += amount;
      }
    }

    var monthlyIncome = Decimal.zero;
    var monthlySpending = Decimal.zero;
    for (final row in transactions) {
      final amount = Decimal.parse('${row['amount'] ?? 0}');
      if (row['type'] == 'income') {
        monthlyIncome += amount;
      } else if (row['type'] == 'expense') {
        monthlySpending += amount;
      }
    }

    var totalBudget = Decimal.zero;
    for (final row in budgets) {
      totalBudget += Decimal.parse('${row['amount'] ?? 0}');
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
    final session = AikoSupabase.requireSession();
    final response = await session.client
        .from('dashboard_widget_preferences')
        .select()
        .eq('user_id', session.userId)
        .eq('dashboard_mode', 'personal')
        .order('position');

    return response
        .map((row) => _preferenceFromRow(Map<String, dynamic>.from(row)))
        .toList(growable: false);
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
    List<dynamic> accounts,
    List<dynamic> transactions,
    List<dynamic> budgets,
  ) {
    for (final rows in [accounts, transactions, budgets]) {
      for (final row in rows) {
        final currency = row['currency'] as String?;
        if (currency != null && currency.isNotEmpty) {
          return currency;
        }
      }
    }
    return 'USD';
  }
}
