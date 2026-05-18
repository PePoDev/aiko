import '../domain/transaction.dart';
import '../domain/transaction_rule.dart';

class TransactionRuleEngine {
  const TransactionRuleEngine();

  List<TransactionRule> matchingRules(
    FinanceTransaction transaction,
    List<TransactionRule> rules,
  ) {
    final active = rules
        .where((rule) => rule.isActive && rule.matches(transaction))
        .toList();
    active.sort((a, b) => a.priority.compareTo(b.priority));
    return active;
  }

  FinanceTransaction applyFirst(
    FinanceTransaction transaction,
    List<TransactionRule> rules,
  ) {
    final match = matchingRules(transaction, rules).firstOrNull;
    if (match == null) {
      return transaction;
    }
    return transaction.copyWith(categoryId: match.targetCategoryId);
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
