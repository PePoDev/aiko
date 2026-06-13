import 'package:aiko/app/app_router.dart';
import 'package:aiko/l10n/app_localizations.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const expectedRoutes = <String, String>{
    '/notifications': 'Notifications',
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

  // Recent refactor regression markers. The 8 older removed-route tests
  // were dropped — they were documenting removals that have been in main
  // for multiple releases and add no ongoing value.
  testWidgets('/bills-subscriptions has been removed', (tester) async {
    await tester.pumpWidget(_routerApp('/bills-subscriptions'));
    await tester.pumpAndSettle();

    expect(find.text('Route not found'), findsOneWidget);
    expect(find.text('Bills & Subscriptions'), findsNothing);
  });

  testWidgets('/bills redirect has been removed', (tester) async {
    await tester.pumpWidget(_routerApp('/bills'));
    await tester.pumpAndSettle();

    expect(find.text('Route not found'), findsOneWidget);
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
