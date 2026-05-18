import '../../../core/money/money.dart';
import '../domain/goal.dart';

class GoalDto {
  const GoalDto(this.json);

  final Map<String, dynamic> json;

  Goal toDomain() {
    final currency = json['currency'] as String? ?? 'USD';
    return Goal(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      purpose: GoalPurpose.values.byName(
        json['purpose'] as String? ?? 'custom',
      ),
      targetAmount: Money.parse('${json['target_amount'] ?? 0}', currency),
      currentAmount: Money.parse('${json['current_amount'] ?? 0}', currency),
      targetDate: DateTime.parse(json['target_date'] as String),
      linkedAccountId: json['linked_account_id'] as String?,
      priority: json['priority'] as int? ?? 1,
      successProbability: (json['success_probability'] as num?)?.toDouble(),
    );
  }
}
