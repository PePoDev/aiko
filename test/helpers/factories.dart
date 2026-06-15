import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/categories/domain/category.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';

/// Tiny domain factories used by tests (T-504). Every test that needs an
/// [Account] / [FinanceTransaction] / [Category] used to hand-build them
/// inline, with subtly different defaults each time, and every change to
/// the domain constructor forced a sweep through the test suite. The
/// factories below centralise the defaults so a constructor change is a
/// one-file diff and a forgotten required field is caught here instead of
/// at the first failing test.
///
/// Note: the legacy `Budget` and `Goal` domain models are gone after the
/// budgets -> categories / goals -> accounts merge (see AGENTS.md). Budgets
/// now live on `Category.monthlyLimit`; goals live on `Account` with
/// `type == AccountType.goal`. The factories reflect that: a budget is
/// just a [Category] with a non-null `monthlyLimit`; a goal is an
/// [Account] with `type = AccountType.goal` plus a `targetAmount` /
/// `targetDate`.
class TestFactories {
  const TestFactories._();

  static Account account({
    String id = 'acc-test',
    String userId = 'user-test',
    String name = 'Test Account',
    AccountType type = AccountType.cash,
    String currency = 'USD',
    Money? currentBalance,
    String? institution,
    bool includeInNetWorth = true,
    bool isActive = true,
    Money? targetAmount,
    DateTime? targetDate,
  }) {
    return Account(
      id: id,
      userId: userId,
      name: name,
      type: type,
      currentBalance: currentBalance ?? Money.parse('0', currency),
      institution: institution,
      includeInNetWorth: includeInNetWorth,
      isActive: isActive,
      targetAmount: targetAmount,
      targetDate: targetDate,
    );
  }

  static FinanceTransaction transaction({
    String id = 'tx-test',
    String userId = 'user-test',
    String accountId = 'acc-test',
    TransactionType type = TransactionType.expense,
    String currency = 'USD',
    Money? amount,
    DateTime? date,
    String? categoryId,
    String? merchant,
    String? note,
  }) {
    return FinanceTransaction(
      id: id,
      userId: userId,
      accountId: accountId,
      type: type,
      amount: amount ?? Money.parse('10', currency),
      date: date ?? DateTime.utc(2026, 6, 1),
      categoryId: categoryId,
      merchant: merchant,
      note: note,
    );
  }

  static Category category({
    String id = 'cat-test',
    String userId = 'user-test',
    String name = 'Test Category',
    CategoryType type = CategoryType.expense,
    CategoryBudgetGroup group = CategoryBudgetGroup.needs,
    String? groupId,
    String icon = 'category',
    String color = '#3B82F6',
    bool budgetEnabled = true,
    bool isActive = true,
    Money? monthlyLimit,
  }) {
    return Category(
      id: id,
      userId: userId,
      name: name,
      type: type,
      group: group,
      groupId: groupId,
      icon: icon,
      color: color,
      budgetEnabled: budgetEnabled,
      isActive: isActive,
      monthlyLimit: monthlyLimit,
    );
  }
}
