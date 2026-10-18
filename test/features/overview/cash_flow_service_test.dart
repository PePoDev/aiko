import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/categories/domain/category.dart';
import 'package:aiko/features/overview/application/cash_flow_service.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final asOf = DateTime(2026, 6, 15);

  FinanceTransaction tx(
    TransactionType type,
    String amount,
    DateTime date, {
    String? categoryId,
  }) => FinanceTransaction(
    id: '$type-$amount-${date.day}',
    userId: 'u',
    accountId: 'a',
    type: type,
    amount: Money.parse(amount, 'USD'),
    date: date,
    categoryId: categoryId,
  );

  Category cat(String id, CategoryBudgetGroup group) => Category(
    id: id,
    userId: 'u',
    name: id,
    type: CategoryType.expense,
    group: group,
  );

  test('sankey buckets outflow by category budget group', () {
    final sankey = const CashFlowService().sankey(
      transactions: [
        tx(TransactionType.income, '4000', DateTime(2026, 6, 1)),
        tx(
          TransactionType.expense,
          '1500',
          DateTime(2026, 6, 2),
          categoryId: 'rent',
        ),
        tx(
          TransactionType.expense,
          '500',
          DateTime(2026, 6, 3),
          categoryId: 'fun',
        ),
        // No category -> Other/custom bucket.
        tx(TransactionType.expense, '200', DateTime(2026, 6, 4)),
        // Internal transfer must not affect cash flow.
        tx(TransactionType.transferOut, '900', DateTime(2026, 6, 5)),
        tx(TransactionType.transferIn, '900', DateTime(2026, 6, 5)),
      ],
      categories: [
        cat('rent', CategoryBudgetGroup.needs),
        cat('fun', CategoryBudgetGroup.wants),
      ],
      asOf: asOf,
    );

    expect(sankey.income, Money.parse('4000', 'USD'));
    expect(sankey.outflowByGroup.first.group, CategoryBudgetGroup.needs);
    expect(sankey.outflowByGroup.first.amount, Money.parse('1500', 'USD'));
    final custom = sankey.outflowByGroup.firstWhere(
      (s) => s.group == CategoryBudgetGroup.custom,
    );
    expect(custom.amount, Money.parse('200', 'USD'));
  });

  test('empty input is inactive', () {
    expect(
      const CashFlowService()
          .sankey(transactions: [], categories: [], asOf: asOf)
          .hasActivity,
      isFalse,
    );
  });
}
