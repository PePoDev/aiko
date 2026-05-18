import '../domain/transaction_rule.dart';

class TransactionRuleDto {
  const TransactionRuleDto(this.json);

  final Map<String, dynamic> json;

  TransactionRule toDomain() {
    return TransactionRule(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['rule_name'] as String,
      conditionType: RuleConditionType.values.byName(
        json['condition_type'] as String? ?? 'merchant',
      ),
      operator: RuleConditionOperator.values.byName(
        json['condition_operator'] as String? ?? 'contains',
      ),
      conditionValue: json['condition_value'] as String,
      targetCategoryId: json['target_category_id'] as String?,
      tagsToApply: List<String>.from(json['tags_to_apply'] as List? ?? []),
      priority: json['priority'] as int? ?? 100,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
