import 'package:aiko/app/app_router.dart';
import 'package:aiko/l10n/app_localizations.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const expectedRoutes = <String, String>{
    '/notifications': 'Notifications',
    '/transactions/search': 'Search Transactions',
    '/transactions/split': 'Split Transaction',
    '/transactions/receipt-review': 'Review Receipt',
    '/budget/pace': 'Pace Overview',
    '/budget/safe-to-spend': 'Safe to Spend',
    '/budget/cash-flow': 'Cash Flow',
    '/budget/cash-flow-sankey': 'Cash Flow Sankey',
    '/goals/detail': 'Goal Detail',
    '/goals/saving-plan': 'Saving Plan',
    '/goals/chance-of-success': 'Chance of Success',
    '/reports/monthly': 'Monthly Report',
    '/aiko-insights': 'Aiko Insights',
    '/loan-calculator': 'Loan Calculator',
    '/calculator-result': 'Calculator Result',
    '/credit-cards/detail': 'Credit Card Detail',
    '/debt-overview': 'Debt Overview',
    '/loans/detail': 'Loans Detail',
    '/net-worth': 'Net Worth Overview',
    '/portfolio/allocation': 'Asset Allocation',
    '/portfolio/holding': 'Holding Detail',
    '/tax-analytics': 'Tax Analytics',
    '/profile-security': 'Profile & Security',
  };

  for (final entry in expectedRoutes.entries) {
    testWidgets('${entry.key} renders ${entry.value}', (tester) async {
      await tester.pumpWidget(_routerApp(entry.key));
      await tester.pumpAndSettle();

      expect(find.text('Route not found'), findsNothing);
      expect(find.text(entry.value), findsWidgets);
    });
  }

  testWidgets('/dashboard/monthly-overview has been removed', (tester) async {
    await tester.pumpWidget(_routerApp('/dashboard/monthly-overview'));
    await tester.pumpAndSettle();

    expect(find.text('Route not found'), findsOneWidget);
    expect(find.text('This Month Overview'), findsNothing);
  });

  testWidgets('/accounting has been removed', (tester) async {
    await tester.pumpWidget(_routerApp('/accounting'));
    await tester.pumpAndSettle();

    expect(find.text('Route not found'), findsOneWidget);
    expect(find.text('Accounting'), findsNothing);
  });
}

Widget _routerApp(String initialLocation) {
  return MaterialApp.router(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AikoTheme.light(),
    routerConfig: createAikoRouter(initialLocation: initialLocation),
  );
}
