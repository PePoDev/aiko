import 'package:aiko/app/app_router.dart';
import 'package:aiko/app/providers.dart';
import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/categories/data/category_repository.dart';
import 'package:aiko/features/categories/domain/category.dart';
import 'package:aiko/features/transactions/data/transaction_repository.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:aiko/l10n/app_localizations.dart';
import 'package:aiko/theme/aiko_colors.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aiko/features/transactions/presentation/transaction_list_screen.dart';

void main() {
  testWidgets('transaction app bar actions use primary action color', (
    tester,
  ) async {
    final theme = AikoTheme.light();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(
            const _FakeTransactionRepository([]),
          ),
        ],
        child: MaterialApp(theme: theme, home: const TransactionListScreen()),
      ),
    );

    await tester.pumpAndSettle();

    for (final icon in [
      Icons.search,
      Icons.account_balance_wallet_outlined,
      Icons.category_outlined,
      Icons.rule,
    ]) {
      final actionIcon = tester.widget<Icon>(
        find.descendant(of: find.byType(AppBar), matching: find.byIcon(icon)),
      );
      expect(actionIcon.color, theme.colorScheme.primary);
    }
    expect(find.byTooltip('Filters'), findsNothing);
  });

  testWidgets('transaction list opens search from the app bar icon', (
    tester,
  ) async {
    final now = DateTime.now();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(
            _FakeTransactionRepository([
              FinanceTransaction(
                id: 'initial',
                userId: 'user',
                accountId: 'cash',
                type: TransactionType.income,
                amount: Money.parse('124.50', 'USD'),
                date: DateTime(now.year, now.month, 17, 9, 30),
                merchant: 'Initial balance',
              ),
              FinanceTransaction(
                id: 'receipt',
                userId: 'user',
                accountId: 'cash',
                type: TransactionType.expense,
                amount: Money.parse('4.50', 'USD'),
                date: DateTime(now.year, now.month, 18),
                merchant: 'Coffee Shop',
              ),
              FinanceTransaction(
                id: 'grocery',
                userId: 'user',
                accountId: 'cash',
                type: TransactionType.expense,
                amount: Money.parse('22.00', 'USD'),
                date: DateTime(now.year, now.month, 19),
                merchant: 'Grocery Market',
              ),
            ]),
          ),
          accountsProvider.overrideWith(
            () => _AccountsNotifier([_cashAccount('98.00')]),
          ),
        ],
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const TransactionListScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Search merchant, note, tag, category'), findsNothing);
    expect(find.byTooltip('Search'), findsOneWidget);
    expect(
      find.text(_monthLabel(DateTime(now.year, now.month))),
      findsOneWidget,
    );
    expect(find.textContaining('Coffee'), findsOneWidget);
    expect(find.textContaining('Grocery'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('-\$4.50')).style?.color,
      AikoColors.dangerRed,
    );
    expect(find.textContaining('EXPENSE'), findsNothing);
    expect(find.textContaining('INCOME'), findsNothing);

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    expect(find.text('Search merchant, note, tag, category'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'coffee');
    await tester.pumpAndSettle();

    expect(find.textContaining('Coffee'), findsOneWidget);
    expect(find.textContaining('Grocery'), findsNothing);
  });

  testWidgets(
    'transaction search uses inline filters instead of duplicate screen',
    (tester) async {
      final now = DateTime.now();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            transactionRepositoryProvider.overrideWithValue(
              _FakeTransactionRepository([
                FinanceTransaction(
                  id: 'salary',
                  userId: 'user',
                  accountId: 'bank',
                  type: TransactionType.income,
                  amount: Money.parse('2500', 'USD'),
                  date: DateTime(now.year, now.month, 5),
                  merchant: 'Acme Payroll',
                ),
                FinanceTransaction(
                  id: 'coffee',
                  userId: 'user',
                  accountId: 'cash',
                  categoryId: 'coffee',
                  type: TransactionType.expense,
                  amount: Money.parse('4.50', 'USD'),
                  date: DateTime(now.year, now.month, 18),
                  merchant: 'Coffee Shop',
                  tags: const ['morning'],
                ),
                FinanceTransaction(
                  id: 'rent',
                  userId: 'user',
                  accountId: 'bank',
                  type: TransactionType.expense,
                  amount: Money.parse('1200', 'USD'),
                  date: DateTime(now.year, now.month, 1),
                  merchant: 'City Rent',
                ),
              ]),
            ),
            accountsProvider.overrideWith(
              () => _AccountsNotifier([
                _cashAccount('98.00'),
                Account(
                  id: 'bank',
                  userId: 'user',
                  name: 'Main Bank',
                  type: AccountType.bank,
                  currentBalance: Money.parse('2500', 'USD'),
                ),
              ]),
            ),
            categoryRepositoryProvider.overrideWithValue(
              const _FakeCategoryRepository([
                Category(
                  id: 'coffee',
                  userId: 'user',
                  name: 'Coffee',
                  type: CategoryType.expense,
                  group: CategoryBudgetGroup.wants,
                  icon: 'coffee',
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

      expect(find.byTooltip('Filters'), findsNothing);
      expect(find.text('Search Transactions'), findsNothing);
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();

      expect(find.text('All'), findsWidgets);
      expect(find.text('Income'), findsWidgets);
      expect(find.text('Expense'), findsWidgets);
      expect(find.text('Transfer'), findsWidgets);
      expect(find.text('Amount'), findsOneWidget);
      expect(find.text('Date'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'coffee');
      await tester.pumpAndSettle();

      expect(find.text('Coffee Shop'), findsOneWidget);
      expect(find.text('Acme Payroll'), findsNothing);
      expect(find.text('City Rent'), findsNothing);

      await tester.tap(find.text('Income').last);
      await tester.pumpAndSettle();

      expect(find.text('No matching transactions'), findsOneWidget);
      expect(find.text('Clear search'), findsOneWidget);

      await tester.tap(find.text('Clear search'));
      await tester.pumpAndSettle();

      expect(find.text('Acme Payroll'), findsOneWidget);
      expect(find.text('Coffee Shop'), findsOneWidget);
      expect(find.text('City Rent'), findsOneWidget);
    },
  );

  testWidgets('transaction list opens categories from the app bar icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(
            const _FakeTransactionRepository([]),
          ),
          categoryRepositoryProvider.overrideWithValue(
            const _FakeCategoryRepository([]),
          ),
        ],
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const TransactionListScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byTooltip('Accounts'), findsOneWidget);
    expect(find.byTooltip('Categories'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byTooltip('Accounts')).dx,
      lessThan(tester.getTopLeft(find.byTooltip('Categories')).dx),
    );
    await tester.tap(find.byTooltip('Categories'));
    await tester.pumpAndSettle();

    expect(find.text('Categories'), findsOneWidget);
    // Dining Out is in the Expense section, which sits below Income in the
    // unified scroll — confirm it is present (offstage is fine, the prior
    // tab layout didn't make it onscreen at the default viewport either).
    expect(find.text('Dining Out', skipOffstage: false), findsOneWidget);
  });

  testWidgets('transaction list opens categories without bottom navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      _transactionsRouterApp(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(
            const _FakeTransactionRepository([]),
          ),
          categoryRepositoryProvider.overrideWithValue(
            const _FakeCategoryRepository([]),
          ),
        ],
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Transactions'), findsWidgets);
    expect(find.text('Aiko'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byTooltip('Categories'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Transactions'), findsNothing);
    expect(find.text('Aiko'), findsNothing);
  });

  testWidgets('transaction list opens accounts without bottom navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      _transactionsRouterApp(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(
            const _FakeTransactionRepository([]),
          ),
          accountsProvider.overrideWith(
            () => _AccountsNotifier([
              Account(
                id: 'cash',
                userId: 'user',
                name: 'Cash Wallet',
                type: AccountType.cash,
                currentBalance: Money.parse('25', 'USD'),
              ),
            ]),
          ),
        ],
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Transactions'), findsWidgets);
    expect(find.text('Aiko'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byTooltip('Accounts'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Accounts'), findsOneWidget);
    expect(find.text('Cash Wallet'), findsOneWidget);
    expect(find.text('Transactions'), findsNothing);
    expect(find.text('Aiko'), findsNothing);
  });

  testWidgets('transaction list plus opens transaction form directly', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(
            const _FakeTransactionRepository([]),
          ),
        ],
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const TransactionListScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.text('Add'), findsNothing);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Item name'), findsOneWidget);
    expect(find.text('Amount'), findsOneWidget);
  });

  testWidgets('transaction item opens detail screen', (tester) async {
    final now = DateTime.now();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(
            _FakeTransactionRepository([
              FinanceTransaction(
                id: 'initial-cash',
                userId: 'user',
                accountId: 'cash',
                type: TransactionType.income,
                amount: Money.parse('124.50', 'USD'),
                date: DateTime(now.year, now.month, 17, 9, 30),
                merchant: 'Initial balance',
              ),
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
          accountsProvider.overrideWith(
            () => _AccountsNotifier([_cashAccount('120.00')]),
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

  testWidgets(
    'deleted transaction is removed from the list after details pop',
    (tester) async {
      final now = DateTime.now();
      final repository = _StaleListAfterDeleteTransactionRepository([
        FinanceTransaction(
          id: 'receipt',
          userId: 'user',
          accountId: 'cash',
          type: TransactionType.expense,
          amount: Money.parse('4.50', 'USD'),
          date: DateTime(now.year, now.month, 18),
          merchant: 'Coffee Shop',
        ),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            transactionRepositoryProvider.overrideWithValue(repository),
            accountsProvider.overrideWith(
              () => _AccountsNotifier([_cashAccount('-4.50')]),
            ),
          ],
          child: MaterialApp(
            theme: AikoTheme.light(),
            home: const TransactionListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Coffee Shop'), findsOneWidget);
      await tester.tap(find.text('Coffee Shop'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete transaction'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(repository.deletedId, 'receipt');
      expect(find.text('Coffee Shop'), findsNothing);
    },
  );

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
          accountsProvider.overrideWith(
            () => _AccountsNotifier([_cashAccount('-20.25')]),
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

  testWidgets('transaction cards show time tag chips and category icon', (
    tester,
  ) async {
    final now = DateTime.now();
    final transactionDate = DateTime(now.year, now.month, 18, 9, 30);
    final expectedTime = DateFormat('HH:mm').format(transactionDate);
    final unexpectedDateTime = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(transactionDate);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(
            _FakeTransactionRepository([
              FinanceTransaction(
                id: 'initial-cash',
                userId: 'user',
                accountId: 'cash',
                type: TransactionType.income,
                amount: Money.parse('124.50', 'USD'),
                date: DateTime(now.year, now.month, 17, 8, 15),
                merchant: 'Initial balance',
              ),
              FinanceTransaction(
                id: 'receipt',
                userId: 'user',
                accountId: 'cash',
                categoryId: 'coffee',
                type: TransactionType.expense,
                amount: Money.parse('4.50', 'USD'),
                date: transactionDate,
                merchant: 'Coffee Shop',
                tags: const ['morning', 'work'],
              ),
            ]),
          ),
          accountsProvider.overrideWith(
            () => _AccountsNotifier([
              Account(
                id: 'cash',
                userId: 'user',
                name: 'Cash Wallet',
                type: AccountType.cash,
                currentBalance: Money.parse('120.00', 'USD'),
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
                group: CategoryBudgetGroup.wants,
                icon: 'coffee',
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

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Coffee Shop'), findsOneWidget);
    expect(find.text('#morning #work'), findsNothing);
    expect(find.text('#morning'), findsOneWidget);
    expect(find.text('#work'), findsOneWidget);
    expect(find.text(expectedTime), findsOneWidget);
    expect(find.text(unexpectedDateTime), findsNothing);
    expect(find.text('Cash Wallet (\$120.00)'), findsOneWidget);
    expect(find.byIcon(Icons.coffee_outlined), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing);

    expect(
      tester.getTopLeft(find.text(expectedTime)).dy,
      greaterThan(tester.getTopLeft(find.text('Coffee Shop')).dy),
    );
    expect(
      tester.getTopLeft(find.text('#morning')).dx,
      greaterThan(tester.getTopRight(find.text(expectedTime)).dx),
    );

    final transactionCard = tester.widget<Card>(
      find
          .ancestor(of: find.text('Coffee Shop'), matching: find.byType(Card))
          .first,
    );
    expect(transactionCard.shape, isA<RoundedRectangleBorder>());
    expect(
      (transactionCard.shape! as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(8),
    );
  });

  testWidgets(
    'transaction cards show forward account balance after each transaction',
    (tester) async {
      final now = DateTime.now();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            transactionRepositoryProvider.overrideWithValue(
              _FakeTransactionRepository([
                FinanceTransaction(
                  id: 'income-50000',
                  userId: 'user',
                  accountId: 'cash',
                  type: TransactionType.income,
                  amount: Money.parse('50000.00', 'USD'),
                  date: DateTime(now.year, now.month, 18, 9),
                  merchant: 'Salary',
                ),
                FinanceTransaction(
                  id: 'expense-500-a',
                  userId: 'user',
                  accountId: 'cash',
                  type: TransactionType.expense,
                  amount: Money.parse('500.00', 'USD'),
                  date: DateTime(now.year, now.month, 19, 9),
                  merchant: 'Groceries',
                ),
                FinanceTransaction(
                  id: 'expense-500-b',
                  userId: 'user',
                  accountId: 'cash',
                  type: TransactionType.expense,
                  amount: Money.parse('500.00', 'USD'),
                  date: DateTime(now.year, now.month, 20, 9),
                  merchant: 'Fuel',
                ),
                FinanceTransaction(
                  id: 'income-200',
                  userId: 'user',
                  accountId: 'cash',
                  type: TransactionType.income,
                  amount: Money.parse('200.00', 'USD'),
                  date: DateTime(now.year, now.month, 21, 9),
                  merchant: 'Refund',
                ),
              ]),
            ),
            accountsProvider.overrideWith(
              () => _AccountsNotifier([
                Account(
                  id: 'cash',
                  userId: 'user',
                  name: 'Cash Wallet',
                  type: AccountType.cash,
                  currentBalance: Money.parse('49200', 'USD'),
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

      expect(find.text('Cash Wallet (\$50,000.00)'), findsOneWidget);
      expect(find.text('Cash Wallet (\$49,500.00)'), findsOneWidget);
      expect(find.text('Cash Wallet (\$49,000.00)'), findsOneWidget);
      expect(find.text('Cash Wallet (\$49,200.00)'), findsOneWidget);
    },
  );

  testWidgets('transactions are grouped by date and sorted by time', (
    tester,
  ) async {
    final now = DateTime.now();
    final newerDate = DateTime(now.year, now.month, 10);
    final olderDate = DateTime(now.year, now.month, 9);
    final eveningDate = DateTime(
      newerDate.year,
      newerDate.month,
      newerDate.day,
      18,
      30,
    );
    final morningDate = DateTime(
      newerDate.year,
      newerDate.month,
      newerDate.day,
      8,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(
            _FakeTransactionRepository([
              FinanceTransaction(
                id: 'morning',
                userId: 'user',
                accountId: 'cash',
                type: TransactionType.expense,
                amount: Money.parse('4.50', 'USD'),
                date: morningDate,
                merchant: 'Morning Coffee',
              ),
              FinanceTransaction(
                id: 'older',
                userId: 'user',
                accountId: 'cash',
                type: TransactionType.expense,
                amount: Money.parse('12.00', 'USD'),
                date: DateTime(
                  olderDate.year,
                  olderDate.month,
                  olderDate.day,
                  12,
                ),
                merchant: 'Older Lunch',
              ),
              FinanceTransaction(
                id: 'evening',
                userId: 'user',
                accountId: 'cash',
                type: TransactionType.expense,
                amount: Money.parse('18.00', 'USD'),
                date: eveningDate,
                merchant: 'Evening Dinner',
              ),
            ]),
          ),
          accountsProvider.overrideWith(
            () => _AccountsNotifier([_cashAccount('-34.50')]),
          ),
        ],
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const TransactionListScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final newerHeader = find.text(_dateHeaderLabel(newerDate));
    final olderHeader = find.text(_dateHeaderLabel(olderDate));

    expect(newerHeader, findsOneWidget);
    expect(olderHeader, findsOneWidget);
    expect(
      tester.getTopLeft(newerHeader).dy,
      lessThan(tester.getTopLeft(olderHeader).dy),
    );
    expect(
      tester.getTopLeft(find.text('Evening Dinner')).dy,
      lessThan(tester.getTopLeft(find.text('Morning Coffee')).dy),
    );
    expect(find.text(DateFormat('HH:mm').format(eveningDate)), findsOneWidget);
    expect(find.text(DateFormat('HH:mm').format(morningDate)), findsOneWidget);
    expect(
      find.text(DateFormat('dd/MM/yyyy HH:mm').format(eveningDate)),
      findsNothing,
    );
    expect(
      find.text(DateFormat('dd/MM/yyyy HH:mm').format(morningDate)),
      findsNothing,
    );
  });
}

class _FakeTransactionRepository extends TransactionRepository {
  const _FakeTransactionRepository(this.transactions);

  final List<FinanceTransaction> transactions;

  @override
  Future<List<FinanceTransaction>> list() async => transactions;
}

class _FakeCategoryRepository extends CategoryRepository {
  const _FakeCategoryRepository(this.categories);

  final List<Category> categories;

  @override
  Future<List<Category>> list() async => categories;

  @override
  Future<Category> save(Category category) async => category;
}

Widget _transactionsRouterApp({required List<Object?> overrides}) {
  return ProviderScope(
    overrides: overrides.cast(),
    child: MaterialApp.router(
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AikoTheme.light(),
      routerConfig: createAikoRouter(initialLocation: '/transactions'),
    ),
  );
}

class _StaleListAfterDeleteTransactionRepository extends TransactionRepository {
  _StaleListAfterDeleteTransactionRepository(
    List<FinanceTransaction> transactions,
  ) : _transactions = List.of(transactions);

  final List<FinanceTransaction> _transactions;
  String? deletedId;

  @override
  Future<List<FinanceTransaction>> list() async =>
      List<FinanceTransaction>.unmodifiable(_transactions);

  @override
  Future<void> delete(String id) async => deletedId = id;
}

Account _cashAccount(String balance) {
  return Account(
    id: 'cash',
    userId: 'user',
    name: 'Cash Wallet',
    type: AccountType.cash,
    currentBalance: Money.parse(balance, 'USD'),
  );
}

class _AccountsNotifier extends AccountsNotifier {
  _AccountsNotifier(List<Account> accounts) : _accounts = List.of(accounts);

  final List<Account> _accounts;

  @override
  Future<List<Account>> build() async => List.unmodifiable(_accounts);

  @override
  Future<void> saveAccount(Account account) async {
    final index = _accounts.indexWhere((item) => item.id == account.id);
    if (index == -1) {
      _accounts.add(account);
    } else {
      _accounts[index] = account;
    }
    state = AsyncValue.data(List.unmodifiable(_accounts));
  }
}

class _CategoriesNotifier extends CategoriesNotifier {
  _CategoriesNotifier(this.categories);

  final List<Category> categories;

  @override
  Future<List<Category>> build() async => categories;
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

String _dateHeaderLabel(DateTime date) {
  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  final dateOnly = DateTime(date.year, date.month, date.day);
  if (dateOnly == todayDate) {
    return 'Today';
  }
  if (dateOnly == todayDate.subtract(const Duration(days: 1))) {
    return 'Yesterday';
  }
  return DateFormat('EEE, MMM d, yyyy').format(dateOnly);
}
