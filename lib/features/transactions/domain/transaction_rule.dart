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
