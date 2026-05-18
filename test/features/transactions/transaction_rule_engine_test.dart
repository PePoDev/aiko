import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/transactions/application/transaction_rule_engine.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:aiko/features/transactions/domain/transaction_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rule engine applies highest priority match', () {
    final transaction = FinanceTransaction(
      id: 'netflix',
      userId: 'user',
      accountId: 'cash',
      type: TransactionType.expense,
      amount: Money.parse('12', 'USD'),
      date: DateTime(2026),
      merchant: 'Netflix',
    );
    const rule = TransactionRule(
      id: 'r1',
      userId: 'user',
      name: 'Netflix',
      conditionType: RuleConditionType.merchant,
      operator: RuleConditionOperator.contains,
      conditionValue: 'netflix',
      targetCategoryId: 'subscriptions',
      priority: 1,
    );

    final applied = const TransactionRuleEngine().applyFirst(transaction, [
      rule,
    ]);

    expect(applied.categoryId, 'subscriptions');
  });
}
