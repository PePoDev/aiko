import 'package:aiko/features/accounts/domain/account_details.dart';
import 'package:aiko/features/accounts/domain/account_type.dart';
import 'package:aiko/features/categories/domain/category.dart';
import 'package:aiko/features/settings/domain/profile.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:aiko/features/transactions/domain/transaction_rule.dart';
import 'package:aiko/l10n/app_localizations.dart';
import 'package:aiko/l10n/domain_labels.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final english = lookupAppLocalizations(const Locale('en'));
  final thai = lookupAppLocalizations(const Locale('th'));
  final thaiScript = RegExp('[฀-๿]');

  final labels = <String, List<String Function(AppLocalizations)>>{
    'AccountType': [for (final v in AccountType.values) v.label],
    'GoalPriority': [for (final v in GoalPriority.values) v.label],
    'RewardsType': [for (final v in RewardsType.values) v.label],
    'LoanType': [for (final v in LoanType.values) v.label],
    'AssetClass': [for (final v in AssetClass.values) v.label],
    'CategoryType': [for (final v in CategoryType.values) v.label],
    'CategoryBudgetGroup': [
      for (final v in CategoryBudgetGroup.values) v.label,
    ],
    'CategoryBudgetPeriod': [
      for (final v in CategoryBudgetPeriod.values) v.label,
    ],
    'TransactionType': [for (final v in TransactionType.values) v.label],
    'RecurringFrequency': [for (final v in RecurringFrequency.values) v.label],
    'RuleConditionType': [for (final v in RuleConditionType.values) v.label],
    'RuleConditionOperator': [
      for (final v in RuleConditionOperator.values) v.label,
    ],
    'Gender': [for (final v in Gender.values) v.label],
    'PreferredTheme': [for (final v in PreferredTheme.values) v.label],
  };

  for (final MapEntry(key: name, value: values) in labels.entries) {
    test('$name values have distinct English and Thai labels', () {
      final en = values.map((label) => label(english)).toList();
      final th = values.map((label) => label(thai)).toList();
      expect(en.toSet(), hasLength(en.length), reason: '$en');
      expect(th.toSet(), hasLength(th.length), reason: '$th');
      expect(th.every(thaiScript.hasMatch), isTrue, reason: '$th');
    });
  }
}
