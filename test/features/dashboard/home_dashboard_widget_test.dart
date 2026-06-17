import 'package:aiko/app/providers.dart';
import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/domain/account.dart';
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

      // The Aiko welcome card moved to the Aiko chat screen.
      expect(find.text('Hi, I am Aiko'), findsNothing);
      expect(find.text('Pace'), findsNothing);
      expect(find.text('Weekly leftover estimate'), findsNothing);
      expect(find.text('Safe this week'), findsOneWidget);
    },
  );

  testWidgets('overview has no edit control and no app bar actions', (
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

    // The dashboard is static now: no layout editing anywhere.
    expect(find.text('Edit layout'), findsNothing);
    expect(find.byTooltip('Remove Daily spending'), findsNothing);

    // The notifications icon lives on the Profile app bar; the Home
    // app bar has no actions.
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.notifications_none),
      ),
      findsNothing,
    );
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

    // 'Safe this week' sits at the top of the layout (position 2) and gets
    // disposed by the lazy ListView once we scroll past it. Assert it
    // exists up front.
    expect(find.text('Safe this week'), findsOneWidget);
    expect(find.text('Total balance'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('This Month Overview'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('This Month Overview'), findsOneWidget);
    expect(find.text('Upcoming due dates'), findsNothing);
    expect(find.text('Total balance'), findsOneWidget);
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
    await tester.scrollUntilVisible(
      find.text('Left to save'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Left to save'), findsOneWidget);
    final cashFlow = find.text('Cash flow');
    for (var i = 0; i < 20 && cashFlow.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
      await tester.pump();
    }
    expect(cashFlow, findsOneWidget);
  });

  testWidgets(
    'home dashboard shows daily spending total derived from transactions',
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
      expect(find.text('\$50.00'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Safe this week'), findsOneWidget);
      expect(find.text('Estimate'), findsOneWidget);

      // Both default half-width panels share one row: same top, side by side.
      expect(
        tester.getTopLeft(find.text('Daily spending')).dy,
        tester.getTopLeft(find.text('Safe this week')).dy,
      );
      expect(
        tester.getTopLeft(find.text('Daily spending')).dx,
        lessThan(tester.getTopLeft(find.text('Safe this week')).dx),
      );

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

  testWidgets(
    'home dashboard shows the Daily spending panel even with no spend',
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

      expect(find.text('Daily spending'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
    },
  );

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
        categories: [
          Category(
            id: 'coffee',
            userId: 'user',
            name: 'Coffee',
            type: CategoryType.expense,
            group: CategoryBudgetGroup.wants,
            color: '#8B5CF6',
            monthlyLimit: Money.parse('100', 'USD'),
            budgetPeriod: CategoryBudgetPeriod.monthly,
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
      transactionsProvider.overrideWith(
        () => _TransactionsNotifier(transactions),
      ),
      categoriesProvider.overrideWith(() => _CategoriesNotifier(categories)),
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

class _AccountsNotifier extends AccountsNotifier {
  _AccountsNotifier(this.accounts);

  final List<Account> accounts;

  @override
  Future<List<Account>> build() async => accounts;
}
