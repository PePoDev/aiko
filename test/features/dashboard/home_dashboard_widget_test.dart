import 'package:aiko/app/providers.dart';
import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/budgets/domain/budget.dart';
import 'package:aiko/features/categories/domain/category.dart';
import 'package:aiko/features/dashboard/domain/dashboard_summary.dart';
import 'package:aiko/features/dashboard/presentation/home_dashboard_screen.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:aiko/l10n/app_localizations.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('home dashboard shows safe-to-spend and Aiko welcome', (
    tester,
  ) async {
    await tester.pumpWidget(
      _dashboardScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AikoTheme.light(),
          home: const HomeDashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Hi, I am Aiko'), findsOneWidget);
    expect(find.text('Safe to spend'), findsOneWidget);
  });

  testWidgets('home dashboard shows daily spending and account count widgets', (
    tester,
  ) async {
    final now = DateTime.now();

    await tester.pumpWidget(
      _dashboardScope(
        budgets: [
          Budget(
            id: Budget.dailySpendingId,
            userId: 'user',
            name: 'Daily Spending',
            categoryId: 'groceries',
            amount: Money.parse('250', 'USD'),
            periodStart: DateTime(now.year, now.month, now.day),
            periodEnd: DateTime(now.year, now.month, now.day, 23, 59, 59),
            period: BudgetPeriod.daily,
            includedCategoryIds: const ['groceries'],
            isAppDefined: true,
          ),
        ],
        accounts: [
          Account(
            id: 'cash',
            userId: 'user',
            name: 'Cash',
            type: AccountType.cash,
            openingBalance: Money.zero('USD'),
            currentBalance: Money.parse('100', 'USD'),
          ),
          Account(
            id: 'bank',
            userId: 'user',
            name: 'Bank',
            type: AccountType.bank,
            openingBalance: Money.zero('USD'),
            currentBalance: Money.parse('500', 'USD'),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AikoTheme.light(),
          home: const HomeDashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Daily spending'), findsOneWidget);
    expect(find.text('\$250.00'), findsOneWidget);
    expect(find.text('Daily limit'), findsOneWidget);
    expect(find.text('Accounts'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Active accounts'), findsOneWidget);
  });

  testWidgets('quick add plus opens the transaction form directly', (
    tester,
  ) async {
    await tester.pumpWidget(
      _dashboardScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AikoTheme.light(),
          home: const HomeDashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Amount'), findsOneWidget);
    expect(find.text('Budget'), findsNothing);
  });

  testWidgets('overview shows transaction analytics widgets', (tester) async {
    final now = DateTime.now();

    await tester.pumpWidget(
      _dashboardScope(
        transactions: [
          FinanceTransaction(
            id: 'income',
            userId: 'user',
            accountId: 'cash',
            type: TransactionType.income,
            amount: Money.parse('100', 'USD'),
            date: DateTime(now.year, now.month, now.day),
          ),
          FinanceTransaction(
            id: 'coffee',
            userId: 'user',
            accountId: 'cash',
            categoryId: 'coffee',
            type: TransactionType.expense,
            amount: Money.parse('25', 'USD'),
            date: DateTime(now.year, now.month, now.day),
          ),
        ],
        categories: const [
          Category(
            id: 'coffee',
            userId: 'user',
            name: 'Coffee',
            type: CategoryType.expense,
            group: CategoryGroup.wants,
            color: '#8B5CF6',
          ),
        ],
        budgets: [
          Budget(
            id: 'budget-coffee',
            userId: 'user',
            name: 'Coffee budget',
            categoryId: 'coffee',
            amount: Money.parse('100', 'USD'),
            periodStart: DateTime(now.year, now.month, 1),
            periodEnd: DateTime(now.year, now.month + 1, 0),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AikoTheme.light(),
          home: const HomeDashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Daily summary'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Daily summary'), findsOneWidget);
    expect(find.text('Net earnings'), findsOneWidget);
    expect(find.textContaining('This month net'), findsOneWidget);
    expect(find.text('Category budgets'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Spending calendar'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Spending calendar'), findsOneWidget);
    expect(find.text('Coffee'), findsOneWidget);
    expect(find.textContaining('Average spending'), findsOneWidget);
    expect(find.textContaining('7 days:'), findsOneWidget);
    expect(find.textContaining('30 days:'), findsOneWidget);
  });

  testWidgets('analytics widget opens detail customization screen', (
    tester,
  ) async {
    final now = DateTime.now();

    await tester.pumpWidget(
      _dashboardScope(
        transactions: [
          FinanceTransaction(
            id: 'coffee',
            userId: 'user',
            accountId: 'cash',
            categoryId: 'coffee',
            type: TransactionType.expense,
            amount: Money.parse('25', 'USD'),
            date: DateTime(now.year, now.month, now.day),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AikoTheme.light(),
          home: const HomeDashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Daily summary'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Daily summary').first);
    await tester.pumpAndSettle();

    expect(find.text('Customize widget'), findsOneWidget);
    expect(find.text('14 days'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Details'),
      320,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Details'), findsOneWidget);
  });
}

Widget _dashboardScope({
  required Widget child,
  List<FinanceTransaction> transactions = const [],
  List<Category> categories = const [],
  List<Budget> budgets = const [],
  List<Account> accounts = const [],
}) {
  return ProviderScope(
    overrides: [
      dashboardSummaryProvider.overrideWith(
        (ref) async => DashboardSummary(
          netWorth: Money.parse('1000', 'USD'),
          totalCash: Money.parse('1000', 'USD'),
          monthlyIncome: Money.parse('5000', 'USD'),
          monthlySpending: Money.parse('1200', 'USD'),
          safeToSpend: Money.parse('300', 'USD'),
          paceStatus: const PaceStatus(
            percentOfBudgetUsed: 40,
            daysElapsedRatio: 0.5,
          ),
        ),
      ),
      dashboardDueItemsProvider.overrideWith((ref) async => const []),
      transactionsProvider.overrideWith(
        () => _TransactionsNotifier(transactions),
      ),
      categoriesProvider.overrideWith(() => _CategoriesNotifier(categories)),
      budgetsProvider.overrideWith(() => _BudgetsNotifier(budgets)),
      accountsProvider.overrideWith(() => _AccountsNotifier(accounts)),
    ],
    child: child,
  );
}

class _TransactionsNotifier extends TransactionsNotifier {
  _TransactionsNotifier(this.transactions);

  final List<FinanceTransaction> transactions;

  @override
  Future<List<FinanceTransaction>> build() async => transactions;
}

class _CategoriesNotifier extends CategoriesNotifier {
  _CategoriesNotifier(this.categories);

  final List<Category> categories;

  @override
  Future<List<Category>> build() async => categories;
}

class _BudgetsNotifier extends BudgetsNotifier {
  _BudgetsNotifier(this.budgets);

  final List<Budget> budgets;

  @override
  Future<List<Budget>> build() async => budgets;
}

class _AccountsNotifier extends AccountsNotifier {
  _AccountsNotifier(this.accounts);

  final List<Account> accounts;

  @override
  Future<List<Account>> build() async => accounts;
}
