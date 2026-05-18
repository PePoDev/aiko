import '../domain/transaction.dart';
import '../domain/transaction_rule.dart';
import 'transaction_rule_engine.dart';

class TransactionRuleService {
  TransactionRuleService(this._engine);

  final TransactionRuleEngine _engine;

  List<FinanceTransaction> preview(
    List<FinanceTransaction> transactions,
    List<TransactionRule> rules,
  ) {
    return [
      for (final transaction in transactions)
        _engine.applyFirst(transaction, rules),
    ];
  }
}
