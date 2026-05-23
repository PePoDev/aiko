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

  testWidgets('quick add opens a floating add menu', (tester) async {
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
    await tester.tap(find.text('Quick add'));
    await tester.pumpAndSettle();

    expect(find.text('Transaction'), findsOneWidget);
    expect(find.text('Budget'), findsOneWidget);
  });

  testWidgets('quick add transaction opens the transaction form directly', (
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
    await tester.tap(find.text('Quick add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transaction'));
    await tester.pump();

    // Check that we're on the transaction form
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Amount'), findsOneWidget);
  });

  testWidgets('quick add budget opens the budget form directly', (
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
    await tester.tap(find.text('Quick add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Budget'));
    await tester.pumpAndSettle();

    expect(find.text('New budget'), findsOneWidget);
  });
}

Widget _dashboardScope({required Widget child}) {
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
      transactionsProvider.overrideWith(() => _EmptyTransactionsNotifier()),
      categoriesProvider.overrideWith(() => _EmptyCategoriesNotifier()),
      accountsProvider.overrideWith(() => _EmptyAccountsNotifier()),
    ],
    child: child,
  );
}

class _EmptyTransactionsNotifier extends TransactionsNotifier {
  @override
  Future<List<FinanceTransaction>> build() async => const [];
}

class _EmptyCategoriesNotifier extends CategoriesNotifier {
  @override
  Future<List<Category>> build() async => const [];
}

class _EmptyAccountsNotifier extends AccountsNotifier {
  @override
  Future<List<Account>> build() async => const [];
}
