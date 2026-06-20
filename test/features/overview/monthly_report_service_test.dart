import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/categories/domain/category.dart';
import 'package:aiko/features/overview/application/monthly_report_service.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = MonthlyReportService();
  final asOf = DateTime(2026, 6, 15);

  FinanceTransaction tx({
    required TransactionType type,
    required String amount,
    required DateTime date,
    String? categoryId,
  }) => FinanceTransaction(
    id: 'id-$amount-${date.millisecondsSinceEpoch}-${type.name}',
    userId: 'u',
    accountId: 'a',
    type: type,
    amount: Money.parse(amount, 'USD'),
    date: date,
    categoryId: categoryId,
  );

  Category cat(String id, String name, String color) => Category(
    id: id,
    userId: 'u',
    name: name,
    type: CategoryType.expense,
    group: CategoryBudgetGroup.wants,
  ).copyWith(color: color);

  test('aggregates this-month income, expenses, net and saved', () {
    final report = service.build(
      transactions: [
        tx(
          type: TransactionType.income,
          amount: '5000',
          date: DateTime(2026, 6, 1),
        ),
        tx(
          type: TransactionType.expense,
          amount: '2000',
          date: DateTime(2026, 6, 5),
          categoryId: 'food',
        ),
        tx(
          type: TransactionType.expense,
          amount: '1000',
          date: DateTime(2026, 6, 9),
          categoryId: 'rent',
        ),
        // Other months ignored.
        tx(
          type: TransactionType.income,
          amount: '999',
          date: DateTime(2026, 5, 1),
        ),
        tx(
          type: TransactionType.expense,
          amount: '999',
          date: DateTime(2026, 7, 1),
        ),
      ],
      categories: [
        cat('food', 'Food', '#16A34A'),
        cat('rent', 'Rent', '#3B82F6'),
      ],
      asOf: asOf,
    );

    expect(report.income, Money.parse('5000', 'USD'));
    expect(report.expenses, Money.parse('3000', 'USD'));
    expect(report.netCashFlow, Money.parse('2000', 'USD'));
    expect(report.saved, Money.parse('2000', 'USD'));
    expect(report.savingsRatePct, closeTo(40, 0.01));
    expect(report.hasActivity, isTrue);
  });

  test('change percent compares to last month, null when no prior data', () {
    final report = service.build(
      transactions: [
        tx(
          type: TransactionType.income,
          amount: '1100',
          date: DateTime(2026, 6, 2),
        ),
        tx(
          type: TransactionType.income,
          amount: '1000',
          date: DateTime(2026, 5, 2),
        ),
        // No expenses last month -> expenses change is null.
        tx(
          type: TransactionType.expense,
          amount: '500',
          date: DateTime(2026, 6, 3),
          categoryId: 'food',
        ),
      ],
      categories: [cat('food', 'Food', '#16A34A')],
      asOf: asOf,
    );

    expect(report.incomeChangePct, closeTo(10, 0.01));
    expect(report.expensesChangePct, isNull);
  });

  test('saved floors at zero when spending exceeds income', () {
    final report = service.build(
      transactions: [
        tx(
          type: TransactionType.income,
          amount: '100',
          date: DateTime(2026, 6, 2),
        ),
        tx(
          type: TransactionType.expense,
          amount: '300',
          date: DateTime(2026, 6, 3),
          categoryId: 'food',
        ),
      ],
      categories: [cat('food', 'Food', '#16A34A')],
      asOf: asOf,
    );

    expect(report.netCashFlow, Money.parse('-200', 'USD'));
    expect(report.saved, Money.zero('USD'));
    expect(report.savingsRatePct, 0);
  });

  test('slices rank expenses by category and fold the rest into Other', () {
    final svc = const MonthlyReportService(maxSlices: 1);
    final report = svc.build(
      transactions: [
        tx(
          type: TransactionType.expense,
          amount: '300',
          date: DateTime(2026, 6, 3),
          categoryId: 'food',
        ),
        tx(
          type: TransactionType.expense,
          amount: '100',
          date: DateTime(2026, 6, 4),
          categoryId: 'rent',
        ),
      ],
      categories: [
        cat('food', 'Food', '#16A34A'),
        cat('rent', 'Rent', '#3B82F6'),
      ],
      asOf: asOf,
    );

    expect(report.slices.length, 2);
    expect(report.slices.first.name, 'Food');
    expect(report.slices.first.amount, Money.parse('300', 'USD'));
    expect(report.slices.last.name, 'Other');
    expect(report.slices.last.amount, Money.parse('100', 'USD'));
  });

  test('empty input is a valid no-activity report', () {
    final report = service.build(transactions: [], categories: [], asOf: asOf);
    expect(report.hasActivity, isFalse);
    expect(report.slices, isEmpty);
    expect(report.income, Money.zero('USD'));
  });
}
