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
                date: DateTime(2026, 5, 18),
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
    expect(find.textContaining('Coffee'), findsOneWidget);
  });

  testWidgets('transaction item opens detail screen', (tester) async {
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
                date: DateTime(2026, 5, 18),
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
}

class _FakeTransactionRepository extends TransactionRepository {
  const _FakeTransactionRepository(this.transactions);

  final List<FinanceTransaction> transactions;

  @override
  Future<List<FinanceTransaction>> list() async => transactions;
}
