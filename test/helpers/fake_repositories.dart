import 'package:aiko/features/accounts/data/account_repository.dart';
import 'package:aiko/features/budgets/data/budget_repository.dart';
import 'package:aiko/features/goals/data/goal_repository.dart';
import 'package:aiko/features/transactions/data/transaction_repository.dart';

class FakeRepositories {
  FakeRepositories()
    : accounts = AccountRepository(),
      transactions = TransactionRepository(),
      budgets = BudgetRepository(),
      goals = GoalRepository();

  final AccountRepository accounts;
  final TransactionRepository transactions;
  final BudgetRepository budgets;
  final GoalRepository goals;
}
