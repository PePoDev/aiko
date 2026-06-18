import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:aiko/features/transactions/domain/transaction_rule.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

FinanceTransaction _tx({String? merchant, List<String> tags = const []}) {
  return FinanceTransaction(
    id: 't1',
    userId: '',
    accountId: 'a1',
    type: TransactionType.expense,
    amount: Money(amount: Decimal.fromInt(5), currency: 'USD'),
    date: DateTime(2026),
    merchant: merchant,
    tags: tags,
  );
}

TransactionRule _rule({
  String? category,
  List<String> tags = const [],
  int priority = 100,
  bool active = true,
  String value = 'starbucks',
}) {
  return TransactionRule(
    id: 'r-$priority',
    userId: '',
    name: 'r',
    conditionType: RuleConditionType.merchant,
    operator: RuleConditionOperator.contains,
    conditionValue: value,
    targetCategoryId: category,
    tagsToApply: tags,
    priority: priority,
    isActive: active,
  );
}

void main() {
  const matcher = TransactionRuleMatcher();

  test('first match by priority sets the category; tags merge', () {
    final result = matcher.apply(_tx(merchant: 'Starbucks Coffee'), [
      _rule(category: 'coffee', tags: ['cafe'], priority: 10),
      _rule(category: 'other', tags: ['drinks'], priority: 20),
    ]);
    expect(result.categoryId, 'coffee'); // higher priority wins
    expect(result.tags, containsAll(<String>['cafe', 'drinks']));
  });

  test('no match leaves the transaction untouched (same instance)', () {
    final tx = _tx(merchant: 'Gas Station');
    expect(identical(matcher.apply(tx, [_rule(category: 'coffee')]), tx), isTrue);
  });

  test('inactive rules are ignored', () {
    final result = matcher.apply(_tx(merchant: 'Starbucks'), [
      _rule(category: 'coffee', active: false),
    ]);
    expect(result.categoryId, isNull);
  });

  test('round-trips through JSON', () {
    final rule = _rule(category: 'coffee', tags: ['cafe'], priority: 5);
    final restored = TransactionRule.fromJson(rule.toJson());
    expect(restored.targetCategoryId, 'coffee');
    expect(restored.tagsToApply, ['cafe']);
    expect(restored.priority, 5);
    expect(restored.conditionType, RuleConditionType.merchant);
  });
}
