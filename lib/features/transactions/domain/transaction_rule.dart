import 'transaction.dart';

enum RuleConditionType {
  merchant,
  keyword,
  amount,
  account,
  category,
  transactionType,
}

enum RuleConditionOperator { contains, equals, startsWith, endsWith }

class TransactionRule {
  const TransactionRule({
    required this.id,
    required this.userId,
    required this.name,
    required this.conditionType,
    required this.operator,
    required this.conditionValue,
    this.targetCategoryId,
    this.tagsToApply = const [],
    this.priority = 100,
    this.isActive = true,
  });

  final String id;
  final String userId;
  final String name;
  final RuleConditionType conditionType;
  final RuleConditionOperator operator;
  final String conditionValue;
  final String? targetCategoryId;
  final List<String> tagsToApply;
  final int priority;
  final bool isActive;

  factory TransactionRule.fromJson(Map<String, dynamic> json) => TransactionRule(
    id: json['id'] as String,
    userId: json['user_id'] as String? ?? '',
    name: json['name'] as String? ?? 'Rule',
    conditionType: RuleConditionType.values.byName(
      json['condition_type'] as String? ?? RuleConditionType.merchant.name,
    ),
    operator: RuleConditionOperator.values.byName(
      json['operator'] as String? ?? RuleConditionOperator.contains.name,
    ),
    conditionValue: json['condition_value'] as String? ?? '',
    targetCategoryId: json['target_category_id'] as String?,
    tagsToApply: List<String>.from(json['tags_to_apply'] as List? ?? const []),
    priority: json['priority'] as int? ?? 100,
    isActive: json['is_active'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'name': name,
    'condition_type': conditionType.name,
    'operator': operator.name,
    'condition_value': conditionValue,
    'target_category_id': targetCategoryId,
    'tags_to_apply': tagsToApply,
    'priority': priority,
    'is_active': isActive,
  };

  bool matches(FinanceTransaction transaction) {
    final value = switch (conditionType) {
      RuleConditionType.merchant => transaction.merchant ?? '',
      RuleConditionType.keyword =>
        '${transaction.merchant ?? ''} ${transaction.note ?? ''}',
      RuleConditionType.account => transaction.accountId,
      RuleConditionType.category => transaction.categoryId ?? '',
      RuleConditionType.transactionType => transaction.type.name,
      RuleConditionType.amount => transaction.amount.amount.toString(),
    };
    return switch (operator) {
      RuleConditionOperator.contains => value.toLowerCase().contains(
        conditionValue.toLowerCase(),
      ),
      RuleConditionOperator.equals =>
        value.toLowerCase() == conditionValue.toLowerCase(),
      RuleConditionOperator.startsWith => value.toLowerCase().startsWith(
        conditionValue.toLowerCase(),
      ),
      RuleConditionOperator.endsWith => value.toLowerCase().endsWith(
        conditionValue.toLowerCase(),
      ),
    };
  }
}

/// Applies a set of rules to a draft transaction: the first matching rule (by
/// ascending priority) sets the category; every match merges its tags.
class TransactionRuleMatcher {
  const TransactionRuleMatcher();

  FinanceTransaction apply(
    FinanceTransaction transaction,
    List<TransactionRule> rules,
  ) {
    final active = rules.where((rule) => rule.isActive).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));

    var categoryId = transaction.categoryId;
    final tags = <String>{...transaction.tags};
    for (final rule in active) {
      if (!rule.matches(transaction)) continue;
      categoryId ??= rule.targetCategoryId;
      tags.addAll(rule.tagsToApply);
    }

    if (categoryId == transaction.categoryId &&
        tags.length == transaction.tags.length) {
      return transaction; // no rule changed anything
    }
    return transaction.copyWith(categoryId: categoryId, tags: tags.toList());
  }
}
