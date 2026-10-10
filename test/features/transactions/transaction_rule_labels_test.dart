import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/categories/domain/category.dart';
import 'package:aiko/features/categories/domain/category_defaults.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:aiko/features/transactions/domain/transaction_rule.dart';
import 'package:aiko/features/transactions/presentation/transaction_rule_labels.dart';
import 'package:aiko/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final accounts = [
    Account(
      id: 'acct-1',
      userId: 'user',
      name: 'KBank Savings',
      type: AccountType.bank,
      currentBalance: Money.parse('0', 'THB'),
    ),
  ];
  final coffee = CategoryDefaults.all.singleWhere(
    (category) => category.id == CategoryDefaults.coffeeId,
  );
  const plants = Category(
    id: 'custom-plants',
    userId: 'user',
    name: 'Plants',
    type: CategoryType.expense,
    group: CategoryBudgetGroup.custom,
  );
  final categories = [coffee, plants];

  TransactionRule rule(
    RuleConditionType type,
    String value, {
    String? targetCategoryId,
  }) => TransactionRule(
    id: 'rule',
    userId: '',
    name: 'Rule',
    conditionType: type,
    operator: RuleConditionOperator.equals,
    conditionValue: value,
    targetCategoryId: targetCategoryId,
  );

  String matchLabel(TransactionRule rule) => ruleConditionValueLabel(
    rule,
    accounts: accounts,
    categories: categories,
    l10n: l10n,
  );

  test('account and category ids are shown by name', () {
    expect(
      matchLabel(rule(RuleConditionType.account, 'acct-1')),
      'KBank Savings',
    );
    expect(
      matchLabel(rule(RuleConditionType.category, CategoryDefaults.coffeeId)),
      'Coffee',
    );
    expect(
      matchLabel(rule(RuleConditionType.transactionType, 'expense')),
      l10n.transactionTypeExpense,
    );
    expect(
      matchLabel(rule(RuleConditionType.merchant, '7-Eleven')),
      '7-Eleven',
    );
  });

  test('missing accounts and categories never show a raw id', () {
    expect(
      matchLabel(rule(RuleConditionType.account, 'gone')),
      l10n.txUnknownAccount,
    );
    expect(
      matchLabel(rule(RuleConditionType.category, 'gone')),
      l10n.uncategorized,
    );
  });

  test('the target category is named, or left unchanged', () {
    expect(
      ruleTargetCategoryLabel(
        rule(RuleConditionType.merchant, 'x', targetCategoryId: plants.id),
        categories: categories,
        l10n: l10n,
      ),
      'Plants',
    );
    expect(
      ruleTargetCategoryLabel(
        rule(RuleConditionType.merchant, 'x'),
        categories: categories,
        l10n: l10n,
      ),
      l10n.rulesLeaveUnchanged,
    );
  });

  test('picked conditions are account, category and transaction type', () {
    expect(
      [
        for (final type in RuleConditionType.values)
          if (rulePicksConditionValue(type)) type,
      ],
      [
        RuleConditionType.account,
        RuleConditionType.category,
        RuleConditionType.transactionType,
      ],
    );
    expect(
      transactionTypeForRuleValue('TRANSFEROUT'),
      TransactionType.transferOut,
    );
    expect(transactionTypeForRuleValue('nope'), isNull);
  });
}
