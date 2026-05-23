import '../../../core/money/money.dart';
import '../domain/budget.dart';

class BudgetDto {
  const BudgetDto(this.json);

  final Map<String, dynamic> json;

  Budget toDomain() {
    final currency = json['currency'] as String? ?? 'THB';
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
      status: BudgetStatus.values.byName(json['status'] as String? ?? 'active'),
      includedCategoryIds: _stringList(json['included_category_ids']),
      isAppDefined: json['is_app_defined'] as bool? ?? false,
    );
  }

  List<String> _stringList(Object? value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList(growable: false);
    }
    return const [];
  }
}
