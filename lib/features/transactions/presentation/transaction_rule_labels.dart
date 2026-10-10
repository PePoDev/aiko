import '../../../l10n/app_localizations.dart';
import '../../../l10n/domain_labels.dart';
import '../../accounts/domain/account.dart';
import '../../categories/domain/category.dart';
import '../../categories/presentation/category_names.dart';
import '../domain/transaction.dart';
import '../domain/transaction_rule.dart';

/// Whether a rule on [type] picks its match value from a list (an account, a
/// category or a transaction type) and compares it exactly, instead of the
/// user typing text.
bool rulePicksConditionValue(RuleConditionType type) => switch (type) {
  RuleConditionType.account ||
  RuleConditionType.category ||
  RuleConditionType.transactionType => true,
  RuleConditionType.merchant ||
  RuleConditionType.keyword ||
  RuleConditionType.amount => false,
};

/// The name of the account with [id], or "Unknown" when it no longer exists.
String ruleAccountName(
  String id,
  Iterable<Account> accounts,
  AppLocalizations l10n,
) {
  for (final account in accounts) {
    if (account.id == id) return account.name;
  }
  return l10n.txUnknownAccount;
}

/// What [rule] matches, for people: account and category ids become names and
/// transaction types their label; typed values are shown as typed.
String ruleConditionValueLabel(
  TransactionRule rule, {
  required Iterable<Account> accounts,
  required Iterable<Category> categories,
  required AppLocalizations l10n,
}) {
  final value = rule.conditionValue;
  return switch (rule.conditionType) {
    RuleConditionType.account => ruleAccountName(value, accounts, l10n),
    RuleConditionType.category => categoryNameForId(value, categories, l10n),
    RuleConditionType.transactionType =>
      transactionTypeForRuleValue(value)?.label(l10n) ?? value,
    RuleConditionType.merchant ||
    RuleConditionType.keyword ||
    RuleConditionType.amount => value,
  };
}

/// The category [rule] sets, by name, or "Leave unchanged" when it sets none.
String ruleTargetCategoryLabel(
  TransactionRule rule, {
  required Iterable<Category> categories,
  required AppLocalizations l10n,
}) {
  final id = rule.targetCategoryId?.trim();
  if (id == null || id.isEmpty) return l10n.rulesLeaveUnchanged;
  return categoryNameForId(id, categories, l10n);
}

/// The transaction type a rule's stored value names (matching ignores case),
/// or null when it names none.
TransactionType? transactionTypeForRuleValue(String value) {
  final lower = value.trim().toLowerCase();
  for (final type in TransactionType.values) {
    if (type.name.toLowerCase() == lower) return type;
  }
  return null;
}
