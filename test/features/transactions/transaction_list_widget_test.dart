import 'package:aiko/app/providers.dart';
import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/transactions/data/transaction_repository.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aiko/features/transactions/presentation/transaction_list_screen.dart';

void main() {
  testWidgets('transaction list shows search and real transaction rows', (
    tester,
  ) async {
    final now = DateTime.now();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(
            _FakeTransactionRepository([
              FinanceTransaction(
                id: 'receipt',
                userId: 'user',
                accountId: 'cash',
                type: TransactionType.expense,
                amount: Money.parse('4.50', 'USD'),
                date: DateTime(now.year, now.month, 18),
                merchant: 'Coffee Shop',
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const TransactionListScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Search transactions'), findsOneWidget);
    expect(
      find.text(_monthLabel(DateTime(now.year, now.month))),
      findsOneWidget,
    );
    expect(find.textContaining('Coffee'), findsOneWidget);
  });

  testWidgets('transaction item opens detail screen', (tester) async {
    final now = DateTime.now();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(
            _FakeTransactionRepository([
              FinanceTransaction(
                id: 'receipt',
                userId: 'user',
                accountId: 'cash',
                type: TransactionType.expense,
                amount: Money.parse('4.50', 'USD'),
                date: DateTime(now.year, now.month, 18),
                merchant: 'Coffee Shop',
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const TransactionListScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Coffee'));
    await tester.pumpAndSettle();

    expect(find.text('Transaction details'), findsOneWidget);
    expect(find.text('Coffee Shop'), findsWidgets);
    expect(find.text('-\$4.50'), findsOneWidget);
  });

  testWidgets('transactions are grouped by month tabs with current selected', (
    tester,
  ) async {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 10);
    final previousMonth = DateTime(now.year, now.month - 1, 12);
    final nextMonth = DateTime(now.year, now.month + 1, 1);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(
            _FakeTransactionRepository([
              FinanceTransaction(
                id: 'current',
                userId: 'user',
                accountId: 'cash',
                type: TransactionType.expense,
                amount: Money.parse('8.25', 'USD'),
                date: currentMonth,
                merchant: 'Current Cafe',
              ),
              FinanceTransaction(
                id: 'previous',
                userId: 'user',
                accountId: 'cash',
                type: TransactionType.expense,
                amount: Money.parse('12.00', 'USD'),
                date: previousMonth,
                merchant: 'Previous Market',
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const TransactionListScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text(_monthLabel(currentMonth)), findsOneWidget);
    expect(find.text(_monthLabel(previousMonth)), findsOneWidget);
    expect(find.text(_monthLabel(nextMonth)), findsOneWidget);
    expect(find.text('Current Cafe'), findsOneWidget);
    expect(find.text('Previous Market'), findsNothing);

    final currentTabCenter = tester.getCenter(
      find.text(_monthLabel(currentMonth)),
    );
    final screenCenter = tester.getCenter(find.byType(TabBar)).dx;
    expect((currentTabCenter.dx - screenCenter).abs(), lessThan(48));

    await tester.tap(find.text(_monthLabel(previousMonth)));
    await tester.pumpAndSettle();

    expect(find.text('Previous Market'), findsOneWidget);
    expect(find.text('Current Cafe'), findsNothing);
  });
}

class _FakeTransactionRepository extends TransactionRepository {
  const _FakeTransactionRepository(this.transactions);

  final List<FinanceTransaction> transactions;

  @override
  Future<List<FinanceTransaction>> list() async => transactions;
}

String _monthLabel(DateTime date) {
  return '${_monthLabels[date.month - 1]} ${date.year}';
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
