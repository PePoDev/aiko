import '../../../core/money/money.dart';
import '../domain/budget.dart';

class BudgetDto {
  const BudgetDto(this.json);

  final Map<String, dynamic> json;

  Budget toDomain() {
    final currency = json['currency'] as String? ?? 'USD';
    return Budget(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      categoryId: json['category_id'] as String,
      amount: Money.parse('${json['amount'] ?? 0}', currency),
      periodStart: DateTime.parse(json['period_start'] as String),
      periodEnd: DateTime.parse(json['period_end'] as String),
      period: BudgetPeriod.values.byName(
        json['period'] as String? ?? 'monthly',
      ),
      alertThresholds: List<int>.from(
        json['alert_thresholds'] as List? ?? [50, 75, 90, 100],
      ),
    );
  }
}
