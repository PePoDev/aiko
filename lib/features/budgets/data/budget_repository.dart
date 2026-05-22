import '../../../core/money/money.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/budget.dart';

class BudgetRepository {
  const BudgetRepository();

  Future<List<Budget>> list() async {
    final session = AikoSupabase.requireSession();
    final response = await session.client
        .from('budgets')
        .select()
        .eq('user_id', session.userId)
        .order('period_start', ascending: false);

    return response
        .map((row) => _fromRow(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<Budget> save(Budget budget) async {
    if (budget.amount.amount <= Money.zero(budget.amount.currency).amount) {
      throw ArgumentError('Budget amount must be positive.');
    }

    final session = AikoSupabase.requireSession();
    final budgetWithUser = Budget(
      id: budget.id,
      userId: session.userId,
      name: budget.name,
      categoryId: budget.categoryId,
      amount: budget.amount,
      periodStart: budget.periodStart,
      periodEnd: budget.periodEnd,
      period: budget.period,
      alertThresholds: budget.alertThresholds,
      status: budget.status,
    );

    await session.client.from('budgets').upsert(_toRow(budgetWithUser));
    return budgetWithUser;
  }

  static Budget _fromRow(Map<String, dynamic> row) {
    final period = BudgetPeriod.values.firstWhere(
      (item) => item.name == (row['period'] as String? ?? 'monthly'),
      orElse: () => BudgetPeriod.monthly,
    );
    final status = BudgetStatus.values.firstWhere(
      (item) => item.name == (row['status'] as String? ?? 'active'),
      orElse: () => BudgetStatus.active,
    );
    final thresholds =
        (row['alert_thresholds'] as List?)
            ?.map((item) => int.parse(item.toString()))
            .toList() ??
        const [50, 75, 90, 100];
    final currency = row['currency'] as String? ?? 'USD';

    return Budget(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      name: row['name'] as String,
      categoryId: row['category_id'] as String? ?? '',
      amount: Money.parse('${row['amount'] ?? 0}', currency),
      periodStart: DateTime.parse(row['period_start'] as String),
      periodEnd: DateTime.parse(row['period_end'] as String),
      period: period,
      alertThresholds: thresholds,
      status: status,
    );
  }

  static Map<String, dynamic> _toRow(Budget budget) {
    return {
      'id': budget.id,
      'user_id': budget.userId,
      'name': budget.name,
      'category_id': budget.categoryId,
      'amount': budget.amount.amount.toString(),
      'currency': budget.amount.currency,
      'period': budget.period.name,
      'period_start': budget.periodStart.toIso8601String().substring(0, 10),
      'period_end': budget.periodEnd.toIso8601String().substring(0, 10),
      'alert_thresholds': budget.alertThresholds,
      'status': budget.status.name,
    };
  }
}
