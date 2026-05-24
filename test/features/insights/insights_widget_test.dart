import 'package:aiko/app/providers.dart';
import 'package:aiko/features/insights/domain/aiko_insight.dart';
import 'package:aiko/features/dashboard/domain/dashboard_summary.dart';
import 'package:aiko/features/dashboard/presentation/home_dashboard_screen.dart';
import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/budgets/domain/budget.dart';
import 'package:aiko/features/categories/domain/category.dart';
import 'package:aiko/features/goals/domain/goal.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:aiko/l10n/app_localizations.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('overview screen shows migrated Aiko insight and review entry', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
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
          goalsProvider.overrideWith(() => _GoalsNotifier()),
          budgetsProvider.overrideWith(() => _BudgetsNotifier()),
          transactionsProvider.overrideWith(() => _TransactionsNotifier()),
          categoriesProvider.overrideWith(() => _CategoriesNotifier()),
          aikoInsightsProvider.overrideWith(
            (ref) async => const [
              AikoInsight(
                id: 'food-up',
                userId: 'user',
                type: AikoInsightType.diagnostic,
                title: 'Food spending increased',
                description:
                    'Food spending increased from real transaction data.',
                recommendation: 'Review recent dining transactions.',
                confidenceScore: 0.82,
                sourceDataSummary: ['transactions'],
              ),
            ],
          ),
        ],
        child: MaterialApp(
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
      find.text('Food spending increased'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Food spending increased'), findsOneWidget);
    expect(find.textContaining('Review'), findsWidgets);
    expect(find.text('Aiko Review'), findsOneWidget);
  });
}

class _GoalsNotifier extends GoalsNotifier {
  @override
  Future<List<Goal>> build() async => const [];
}

class _BudgetsNotifier extends BudgetsNotifier {
  @override
  Future<List<Budget>> build() async => const [];
}

class _TransactionsNotifier extends TransactionsNotifier {
  @override
  Future<List<FinanceTransaction>> build() async => const [];
}

class _CategoriesNotifier extends CategoriesNotifier {
  @override
  Future<List<Category>> build() async => const [];
}
