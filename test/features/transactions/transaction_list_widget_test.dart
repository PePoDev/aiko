import 'package:aiko/app/providers.dart';
import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/categories/data/category_repository.dart';
import 'package:aiko/features/categories/domain/category.dart';
import 'package:aiko/features/transactions/data/transaction_repository.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:aiko/theme/aiko_colors.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aiko/features/transactions/presentation/transaction_list_screen.dart';

void main() {
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
        ],
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const TransactionListScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Search transactions'), findsNothing);
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

    expect(find.text('Search transactions'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'coffee');
    await tester.pumpAndSettle();

    expect(find.textContaining('Coffee'), findsOneWidget);
    expect(find.textContaining('Grocery'), findsNothing);
  });

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

    expect(find.byTooltip('Categories'), findsOneWidget);
    await tester.tap(find.byTooltip('Categories'));
    await tester.pumpAndSettle();

    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('No categories yet'), findsOneWidget);
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

  testWidgets('transaction cards show tags account balance and category icon', (
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
                categoryId: 'coffee',
                type: TransactionType.expense,
                amount: Money.parse('4.50', 'USD'),
                date: DateTime(now.year, now.month, 18, 9, 30),
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
                openingBalance: Money.zero('USD'),
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
                group: CategoryGroup.wants,
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

    expect(find.text('#morning #work'), findsOneWidget);
    expect(find.text('Cash Wallet (\$120.00)'), findsOneWidget);
    expect(find.byIcon(Icons.coffee_outlined), findsOneWidget);
    expect(find.textContaining('09:30'), findsNothing);
  });

  testWidgets('transactions are grouped by date and sorted by time', (
    tester,
  ) async {
    final now = DateTime.now();
    final newerDate = DateTime(now.year, now.month, 10);
    final olderDate = DateTime(now.year, now.month, 9);

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
                date: DateTime(
                  newerDate.year,
                  newerDate.month,
                  newerDate.day,
                  8,
                ),
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
                date: DateTime(
                  newerDate.year,
                  newerDate.month,
                  newerDate.day,
                  18,
                  30,
                ),
                merchant: 'Evening Dinner',
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
    expect(find.textContaining('18:30'), findsNothing);
    expect(find.textContaining('08:00'), findsNothing);
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
