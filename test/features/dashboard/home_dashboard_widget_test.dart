import 'package:aiko/app/providers.dart';
import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/budgets/domain/budget.dart';
import 'package:aiko/features/categories/domain/category.dart';
import 'package:aiko/features/dashboard/domain/dashboard_summary.dart';
import 'package:aiko/features/dashboard/domain/dashboard_widget_preference.dart';
import 'package:aiko/features/dashboard/presentation/home_dashboard_screen.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:aiko/l10n/app_localizations.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets(
    'home dashboard shows Aiko welcome without duplicate weekly leftover card',
    (tester) async {
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
      expect(find.text('Pace'), findsNothing);
      expect(find.text('Weekly leftover estimate'), findsNothing);
      expect(find.text('Safe this week'), findsOneWidget);
    },
  );

  testWidgets('overview uses scroll edit control and primary app bar icons', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final theme = AikoTheme.light();

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
          theme: theme,
          home: const HomeDashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Edit layout'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Edit layout'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.calendar_month_outlined),
      ),
      findsNothing,
    );

    final notificationIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.notifications_none),
      ),
    );
    expect(notificationIcon.color, theme.colorScheme.primary);

    await tester.scrollUntilVisible(
      find.text('Edit layout'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Edit layout'), findsOneWidget);
  });

  testWidgets('overview shows this month summary after upcoming due dates', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

    expect(find.text('Total balance'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('This Month Overview'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('This Month Overview'), findsOneWidget);
    expect(find.text('Upcoming due dates'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Upcoming due dates')).dy,
      lessThan(tester.getTopLeft(find.text('This Month Overview')).dy),
    );
    expect(find.text('Total balance'), findsOneWidget);
    expect(find.text('Safe this week'), findsOneWidget);
    expect(find.text('Left to save'), findsOneWidget);
    expect(find.text('Cash flow'), findsOneWidget);
    final monthOverviewCard = find
        .ancestor(
          of: find.text('This Month Overview'),
          matching: find.byType(Card),
        )
        .first;
    expect(
      find.descendant(of: monthOverviewCard, matching: find.text('Income')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: monthOverviewCard, matching: find.text('Expenses')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: monthOverviewCard, matching: find.text('Savings')),
      findsOneWidget,
    );
  });

  testWidgets('overview editor manages each overview panel separately', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
    await tester.scrollUntilVisible(
      find.text('Edit layout'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Edit layout'));
    await tester.pumpAndSettle();

    for (final tooltip in const [
      'Remove Daily spending',
      'Remove Safe this week',
      'Remove Daily summary',
      'Remove Net earnings',
      'Remove Category budgets',
      'Remove Spending calendar',
      'Remove This Month Overview',
      'Remove Cash flow mapping',
      'Remove Aiko Goal Simulator',
    ]) {
      final finder = find.byTooltip(tooltip);
      for (
        var attempt = 0;
        attempt < 20 && finder.evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
        await tester.pumpAndSettle();
      }
      expect(find.byTooltip(tooltip), findsOneWidget);
    }
  });

  testWidgets(
    'home dashboard shows daily spending gauge and safe week summary',
    (tester) async {
      final now = DateTime.now();

      await tester.pumpWidget(
        _dashboardScope(
          transactions: [
            FinanceTransaction(
              id: 'groceries-today',
              userId: 'user',
              accountId: 'cash',
              categoryId: 'groceries',
              type: TransactionType.expense,
              amount: Money.parse('40', 'USD'),
              date: DateTime(now.year, now.month, now.day, 12),
            ),
            FinanceTransaction(
              id: 'coffee-today',
              userId: 'user',
              accountId: 'cash',
              categoryId: 'coffee',
              type: TransactionType.expense,
              amount: Money.parse('10', 'USD'),
              date: DateTime(now.year, now.month, now.day, 12),
            ),
          ],
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
      expect(find.text('\$40.00 / \$250.00'), findsOneWidget);
      expect(find.text('Current / limit'), findsOneWidget);
      final dailySpendingCard = find
          .ancestor(
            of: find.text('Daily spending'),
            matching: find.byType(Card),
          )
          .first;
      final indicator = tester.widget<LinearProgressIndicator>(
        find
            .descendant(
              of: dailySpendingCard,
              matching: find.byType(LinearProgressIndicator),
            )
            .first,
      );
      expect(indicator.value, 0.16);
      expect(find.text('Accounts'), findsNothing);
      expect(find.text('Today'), findsNothing);
      expect(find.text('Safe this week'), findsOneWidget);
      expect(find.text('Estimate'), findsOneWidget);

      final miniCard = tester.widget<Card>(
        find
            .ancestor(
              of: find.text('Safe this week'),
              matching: find.byType(Card),
            )
            .first,
      );
      expect(
        find.descendant(
          of: find
              .ancestor(
                of: find.text('Safe this week'),
                matching: find.byType(Card),
              )
              .first,
          matching: find.text('\$300.00'),
        ),
        findsOneWidget,
      );
      expect(miniCard.shape, isA<RoundedRectangleBorder>());
      expect(
        (miniCard.shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(8),
      );
    },
  );

  testWidgets('home dashboard asks user to set up daily spending budget', (
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

    expect(find.text('Daily spending'), findsOneWidget);
    expect(
      find.text('Set up Daily Spending to track today\'s limit'),
      findsOneWidget,
    );
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

    expect(find.text('Item name'), findsOneWidget);
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
    expect(find.textContaining('Average spending'), findsOneWidget);
    expect(find.textContaining('7 days:'), findsOneWidget);
    expect(find.textContaining('30 days:'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Net earnings'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Net earnings'), findsOneWidget);
    expect(find.textContaining('This month net'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Category budgets'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Category budgets'), findsOneWidget);
    expect(find.text('Coffee'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Spending calendar'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Spending calendar'), findsOneWidget);
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
      dashboardLayoutProvider.overrideWith(_DashboardLayoutNotifier.new),
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

class _DashboardLayoutNotifier extends DashboardLayoutNotifier {
  @override
  Future<List<DashboardWidgetPreference>> build() async {
    return DashboardWidgetPreference.defaultLayout;
  }
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
