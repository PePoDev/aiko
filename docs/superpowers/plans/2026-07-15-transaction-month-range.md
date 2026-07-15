# Transaction Month Range Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show transaction tabs from the oldest saved transaction month through at least 12 months after the current month so recurring previews are visible for the next year.

**Architecture:** Add a pure application-layer service that calculates an ordered, inclusive range of calendar months from saved transactions and an explicit current date. The Transactions screen will consume that service while retaining ownership of labels, tab selection, real-transaction filtering, and the existing recurring preview rendering.

**Tech Stack:** Dart 3.11, Flutter Material tabs, `flutter_test`, existing `FinanceTransaction` domain model

## Global Constraints

- The current month is always included and initially selected.
- The past boundary is the earlier of the current month and the oldest saved transaction month.
- The future boundary is the later of 12 months after the current month and the newest saved transaction month.
- With no transactions, show the current month plus the following 12 months.
- Keep the range continuous, inclusive, and ordered from oldest to newest.
- Reuse `RecurringProjection`; do not change recurrence, persistence, search, authentication, or transaction-form behavior.
- Follow the repository rule prohibiting widget tests; test the extracted month-range logic with unit tests.
- Do not add dependencies.

## File Structure

- Create `lib/features/transactions/application/transaction_month_range.dart` for the calendar-month value and pure range calculation.
- Create `test/features/transactions/transaction_month_range_test.dart` for deterministic logic-only coverage.
- Modify `lib/features/transactions/presentation/transaction_list_screen.dart` to consume the service and keep display labels in the presentation layer.

---

### Task 1: Add the tested month-range service

**Files:**
- Create: `lib/features/transactions/application/transaction_month_range.dart`
- Test: `test/features/transactions/transaction_month_range_test.dart`

**Interfaces:**
- Consumes: `FinanceTransaction.date`, `DateTime currentDate`
- Produces: `TransactionMonth.fromDate(DateTime)`, `TransactionMonth.addMonths(int)`, and `TransactionMonthRangeService.monthsFor({required Iterable<FinanceTransaction> transactions, required DateTime currentDate}) -> List<TransactionMonth>`

- [x] **Step 1: Write the failing unit tests**

Create `test/features/transactions/transaction_month_range_test.dart`:

```dart
import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/transactions/application/transaction_month_range.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

FinanceTransaction _transaction(String id, DateTime date) {
  return FinanceTransaction(
    id: id,
    userId: 'user',
    accountId: 'account',
    type: TransactionType.expense,
    amount: Money.parse('10', 'USD'),
    date: date,
  );
}

void main() {
  const service = TransactionMonthRangeService();
  final currentDate = DateTime(2026, 7, 15);

  test('empty history includes current month and twelve future months', () {
    final months = service.monthsFor(
      transactions: const <FinanceTransaction>[],
      currentDate: currentDate,
    );

    expect(months, hasLength(13));
    expect(months.first, const TransactionMonth(2026, 7));
    expect(months.last, const TransactionMonth(2027, 7));
  });

  test('history starts at the oldest saved transaction month', () {
    final months = service.monthsFor(
      transactions: [
        _transaction('newer', DateTime(2026, 5, 20)),
        _transaction('oldest', DateTime(2024, 3, 8)),
      ],
      currentDate: currentDate,
    );

    expect(months.first, const TransactionMonth(2024, 3));
    expect(months.last, const TransactionMonth(2027, 7));
    expect(months, contains(const TransactionMonth(2026, 7)));
    expect(months, hasLength(41));
  });

  test('future-only data still starts at the current month', () {
    final months = service.monthsFor(
      transactions: [_transaction('future', DateTime(2027, 1, 3))],
      currentDate: currentDate,
    );

    expect(months.first, const TransactionMonth(2026, 7));
    expect(months.last, const TransactionMonth(2027, 7));
  });

  test('saved transaction beyond one year extends the future boundary', () {
    final months = service.monthsFor(
      transactions: [_transaction('far-future', DateTime(2028, 9, 2))],
      currentDate: currentDate,
    );

    expect(months.first, const TransactionMonth(2026, 7));
    expect(months.last, const TransactionMonth(2028, 9));
    for (var index = 1; index < months.length; index++) {
      expect(months[index], months[index - 1].addMonths(1));
    }
  });

  test('month arithmetic crosses year boundaries in both directions', () {
    expect(
      const TransactionMonth(2026, 12).addMonths(1),
      const TransactionMonth(2027, 1),
    );
    expect(
      const TransactionMonth(2027, 1).addMonths(-1),
      const TransactionMonth(2026, 12),
    );
  });
}
```

- [x] **Step 2: Run the focused tests and verify RED**

Run:

```bash
flutter test test/features/transactions/transaction_month_range_test.dart
```

Expected: FAIL because `transaction_month_range.dart`, `TransactionMonth`, and `TransactionMonthRangeService` do not exist.

- [x] **Step 3: Implement the pure month-range service**

Create `lib/features/transactions/application/transaction_month_range.dart`:

```dart
import '../domain/transaction.dart';

class TransactionMonth implements Comparable<TransactionMonth> {
  const TransactionMonth(this.year, this.month)
    : assert(month >= 1 && month <= 12, 'month must be between 1 and 12');

  factory TransactionMonth.fromDate(DateTime date) {
    return TransactionMonth(date.year, date.month);
  }

  final int year;
  final int month;

  TransactionMonth addMonths(int offset) {
    final date = DateTime(year, month + offset);
    return TransactionMonth(date.year, date.month);
  }

  @override
  int compareTo(TransactionMonth other) {
    final yearComparison = year.compareTo(other.year);
    return yearComparison != 0 ? yearComparison : month.compareTo(other.month);
  }

  @override
  bool operator ==(Object other) {
    return other is TransactionMonth &&
        other.year == year &&
        other.month == month;
  }

  @override
  int get hashCode => Object.hash(year, month);
}

class TransactionMonthRangeService {
  const TransactionMonthRangeService();

  List<TransactionMonth> monthsFor({
    required Iterable<FinanceTransaction> transactions,
    required DateTime currentDate,
  }) {
    final currentMonth = TransactionMonth.fromDate(currentDate);
    var firstMonth = currentMonth;
    var lastMonth = currentMonth.addMonths(12);

    for (final transaction in transactions) {
      final transactionMonth = TransactionMonth.fromDate(transaction.date);
      if (transactionMonth.compareTo(firstMonth) < 0) {
        firstMonth = transactionMonth;
      }
      if (transactionMonth.compareTo(lastMonth) > 0) {
        lastMonth = transactionMonth;
      }
    }

    return [
      for (
        var month = firstMonth;
        month.compareTo(lastMonth) <= 0;
        month = month.addMonths(1)
      )
        month,
    ];
  }
}
```

- [x] **Step 4: Format and verify GREEN**

Run:

```bash
dart format lib/features/transactions/application/transaction_month_range.dart test/features/transactions/transaction_month_range_test.dart
flutter test test/features/transactions/transaction_month_range_test.dart
```

Expected: five tests PASS.

- [x] **Step 5: Commit the service and tests**

```bash
git add lib/features/transactions/application/transaction_month_range.dart test/features/transactions/transaction_month_range_test.dart
git commit -m "feat: calculate transaction month range"
```

---

### Task 2: Integrate the calculated range into the Transactions screen

**Files:**
- Modify: `lib/features/transactions/presentation/transaction_list_screen.dart:8-14,239-330,520-650,1066-1115`
- Test: `test/features/transactions/transaction_month_range_test.dart`

**Interfaces:**
- Consumes: `const TransactionMonthRangeService().monthsFor(...) -> List<TransactionMonth>` and `TransactionMonth.fromDate(DateTime)` from Task 1
- Produces: a continuous tab range from the required past boundary through the required future boundary; no public UI API changes

- [x] **Step 1: Import and consume the month-range service**

Add the application import beside `recurring_projection.dart`:

```dart
import '../application/recurring_projection.dart';
import '../application/transaction_month_range.dart';
```

Replace the start of `_MonthlyTransactionTabs.build` and the tab label expression with:

```dart
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentMonth = TransactionMonth.fromDate(now);
    final months = const TransactionMonthRangeService().monthsFor(
      transactions: transactions,
      currentDate: now,
    );
    final initialIndex = months.indexOf(currentMonth);

    return DefaultTabController(
      length: months.length,
      initialIndex: initialIndex < 0 ? 0 : initialIndex,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              tabs: [for (final month in months) Tab(text: _monthLabel(month))],
            ),
          ),
```

Delete `_MonthlyTransactionTabs._monthKeysFor`; the application service now owns that calculation.

- [x] **Step 2: Replace the private month key with `TransactionMonth`**

Replace `_transactionsForMonth` with:

```dart
  static List<FinanceTransaction> _transactionsForMonth(
    TransactionMonth month,
    List<FinanceTransaction> transactions,
  ) {
    return transactions
        .where(
          (transaction) =>
              TransactionMonth.fromDate(transaction.date) == month,
        )
        .toList(growable: false);
  }
```

Change `_TransactionMonthPage.month` to:

```dart
  final TransactionMonth month;
```

Replace both `widget.month.label` expressions with `_monthLabel(widget.month)`:

```dart
                  : 'No transactions in ${_monthLabel(widget.month)}',
```

```dart
          monthLabel: _monthLabel(widget.month),
```

Delete the entire private `_MonthKey` class. Keep `_monthLabels`, and add this presentation-only formatter immediately before it:

```dart
String _monthLabel(TransactionMonth month) {
  return '${_monthLabels[month.month - 1]} ${month.year}';
}

const _monthLabels = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
```

- [x] **Step 3: Format and run focused verification**

Run:

```bash
dart format lib/features/transactions/application/transaction_month_range.dart lib/features/transactions/presentation/transaction_list_screen.dart test/features/transactions/transaction_month_range_test.dart
flutter test test/features/transactions/transaction_month_range_test.dart test/features/transactions/recurring_projection_test.dart
```

Expected: all month-range and recurring-projection tests PASS. Formatting may normalize pre-existing formatting in `transaction_list_screen.dart`; inspect the diff and keep only mechanical formatting plus the planned integration.

- [x] **Step 4: Run the full quality gates**

Run:

```bash
git diff --check
flutter analyze
flutter test
```

Expected: no whitespace errors, `flutter analyze` reports `No issues found!`, and all tests PASS.

- [x] **Step 5: Commit the screen integration**

```bash
git add lib/features/transactions/presentation/transaction_list_screen.dart
git commit -m "feat: extend transaction month tabs"
```
