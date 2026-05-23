import 'package:aiko/app/authenticated_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  GoRouter buildRouter() {
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
              builder: (context, state) => const Text('Transactions page'),
            ),
            GoRoute(
              path: '/aiko',
              builder: (context, state) => const Text('Ask Aiko page'),
            ),
            GoRoute(
              path: '/insights',
              builder: (context, state) => const Text('Insights page'),
            ),
            GoRoute(
              path: '/more',
              builder: (context, state) => const Text('Aiko Hub page'),
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

  testWidgets('bottom navigation uses insights instead of budget', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp.router(
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        routerConfig: buildRouter(),
      ),
    );

    expect(find.text('Insights'), findsOneWidget);
    expect(find.text('Budget'), findsNothing);

    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();

    expect(find.text('Insights page'), findsOneWidget);
  });
}
