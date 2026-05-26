import 'package:aiko/app/authenticated_shell.dart';
import 'package:aiko/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  var transactionsBuildCount = 0;

  GoRouter buildRouter() {
    transactionsBuildCount = 0;
    return GoRouter(
      initialLocation: '/home',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AuthenticatedShell(child: child),
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const Text('Home page'),
            ),
            GoRoute(
              path: '/transactions',
              builder: (context, state) {
                transactionsBuildCount++;
                return Text('Transactions page $transactionsBuildCount');
              },
            ),
            GoRoute(
              path: '/aiko',
              builder: (context, state) => const Text('Ask Aiko page'),
            ),
            GoRoute(
              path: '/planning',
              builder: (context, state) => const Text('Planning page'),
            ),
            GoRoute(
              path: '/settings',
              builder: (context, state) => const Text('Settings page'),
            ),
            GoRoute(
              path: '/budget',
              builder: (context, state) => const Text('Budget page'),
            ),
          ],
        ),
      ],
    );
  }

  testWidgets('bottom navigation uses planning and settings tabs', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        routerConfig: buildRouter(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Planning'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Insights'), findsNothing);

    await tester.tap(find.text('Planning'));
    await tester.pumpAndSettle();

    expect(find.text('Planning page'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings page'), findsOneWidget);
  });

  testWidgets('tapping active transactions tab reopens transactions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        routerConfig: buildRouter(),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Transactions'));
    await tester.pumpAndSettle();

    expect(find.text('Transactions page 1'), findsOneWidget);

    await tester.tap(find.text('Transactions'));
    await tester.pumpAndSettle();

    expect(find.text('Transactions page 2'), findsOneWidget);
  });
}
