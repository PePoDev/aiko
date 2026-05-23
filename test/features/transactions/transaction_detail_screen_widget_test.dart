import 'package:aiko/app/providers.dart';
import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/categories/domain/category.dart';
import 'package:aiko/features/transactions/data/transaction_repository.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:aiko/features/transactions/presentation/transaction_detail_screen.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('details screen shows account and category in summary only', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(
            _FakeTransactionRepository(),
          ),
          accountsProvider.overrideWith(
            () => _AccountsNotifier([
              Account(
                id: 'cash',
                userId: 'user',
                name: 'Cash Wallet',
                type: AccountType.cash,
                openingBalance: Money.zero('USD'),
                currentBalance: Money.zero('USD'),
              ),
            ]),
          ),
          categoriesProvider.overrideWith(
            () => _CategoriesNotifier([
              const Category(
                id: 'coffee',
                userId: 'user',
                name: 'Coffee',
                type: CategoryType.expense,
                group: CategoryGroup.wants,
                icon: 'coffee',
                color: '#8B5CF6',
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: TransactionDetailScreen(
            transaction: FinanceTransaction(
              id: 'tx-1',
              userId: 'user',
              accountId: 'cash',
              categoryId: 'coffee',
              type: TransactionType.expense,
              amount: Money.parse('4.50', 'USD'),
              date: DateTime(2026, 5, 23, 9, 30),
              merchant: 'Cafe',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Details'), findsNothing);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Cash Wallet'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Coffee'), findsOneWidget);
    expect(find.byKey(const Key('transaction-category-icon')), findsOneWidget);
    expect(find.byIcon(Icons.coffee_outlined), findsOneWidget);
  });

  testWidgets('details screen can edit a transaction', (tester) async {
    final repository = _FakeTransactionRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(repository),
          accountsProvider.overrideWith(
            () => _AccountsNotifier([
              Account(
                id: 'cash',
                userId: 'user',
                name: 'Cash Wallet',
                type: AccountType.cash,
                openingBalance: Money.zero('USD'),
                currentBalance: Money.zero('USD'),
              ),
            ]),
          ),
          categoriesProvider.overrideWith(
            () => _CategoriesNotifier([
              const Category(
                id: 'coffee',
                userId: 'user',
                name: 'Coffee',
                type: CategoryType.expense,
                group: CategoryGroup.wants,
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: TransactionDetailScreen(
            transaction: FinanceTransaction(
              id: 'tx-1',
              userId: 'user',
              accountId: 'cash',
              categoryId: 'coffee',
              type: TransactionType.expense,
              amount: Money.parse('4.50', 'USD'),
              date: DateTime(2026, 5, 23, 9, 30),
              merchant: 'Cafe',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit transaction'));
    await tester.pumpAndSettle();

    expect(find.text('Edit transaction'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Tea Bar');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    final saveButton = find.widgetWithText(FilledButton, 'Save Changes');
    await tester.scrollUntilVisible(
      saveButton,
      320,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(repository.savedTransaction?.merchant, 'Tea Bar');
    expect(find.text('Tea Bar'), findsOneWidget);
    expect(find.text('Cafe'), findsNothing);
  });
}

class _AccountsNotifier extends AccountsNotifier {
  _AccountsNotifier(this.accounts);

  final List<Account> accounts;

  @override
  Future<List<Account>> build() async => accounts;
}

class _CategoriesNotifier extends CategoriesNotifier {
  _CategoriesNotifier(this.categories);

  final List<Category> categories;

  @override
  Future<List<Category>> build() async => categories;
}

class _FakeTransactionRepository extends TransactionRepository {
  FinanceTransaction? savedTransaction;

  @override
  Future<List<FinanceTransaction>> list() async {
    return savedTransaction == null ? const [] : [savedTransaction!];
  }

  @override
  Future<FinanceTransaction> save(FinanceTransaction transaction) async {
    savedTransaction = transaction;
    return transaction;
  }
}
