import 'package:aiko/app/authenticated_shell.dart';
import 'package:aiko/l10n/app_localizations.dart';
import 'package:aiko/theme/aiko_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  var transactionsBuildCount = 0;

  GoRouter buildRouter({String initialLocation = '/home'}) {
    transactionsBuildCount = 0;
    return GoRouter(
      initialLocation: initialLocation,
      routes: [
        ShellRoute(
          builder: (context, state, child) => AuthenticatedShell(child: child),
          routes: [
            GoRoute(
              path: '/accounts',
              builder: (context, state) => const Text('Accounts page'),
            ),
            GoRoute(
              path: '/categories',
              builder: (context, state) => const Text('Categories page'),
            ),
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

  testWidgets('bottom navigation uses accounts, categories, overview, '
      'transactions, aiko tabs', (tester) async {
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

    for (final label in [
      'Accounts',
      'Categories',
      'Overview',
      'Transactions',
      'Aiko',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Planning'), findsNothing);
    expect(find.text('Menu'), findsNothing);

    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();
    expect(find.text('Accounts page'), findsOneWidget);

    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();
    expect(find.text('Categories page'), findsOneWidget);

    await tester.tap(find.text('Aiko'));
    await tester.pumpAndSettle();
    expect(find.text('Ask Aiko page'), findsOneWidget);
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

  testWidgets('selected tab renders a primary-colored indicator bar', (
    tester,
  ) async {
    const primary = Color(0xFF1565C0);
    final expectedScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    );
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
        theme: ThemeData(
          splashFactory: InkRipple.splashFactory,
          colorScheme: expectedScheme,
        ),
        routerConfig: buildRouter(initialLocation: '/accounts'),
      ),
    );
    await tester.pumpAndSettle();

    final indicator = find.byKey(const ValueKey('AikoNavIndicator_/accounts'));
    expect(indicator, findsOneWidget);
    expect(tester.getSize(indicator).width, 32);
    expect(tester.getSize(indicator).height, 3);

    final container = tester.widget<AnimatedContainer>(indicator);
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, expectedScheme.primary);
  });

  testWidgets('selected aiko tab renders a purple indicator bar', (
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
        routerConfig: buildRouter(initialLocation: '/aiko'),
      ),
    );
    await tester.pumpAndSettle();

    final indicator = find.byKey(const ValueKey('AikoNavIndicator_/aiko'));
    final container = tester.widget<AnimatedContainer>(indicator);
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, AikoColors.premiumPurple);
  });

  testWidgets('unselected tabs render a zero-width indicator', (tester) async {
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

    final accountsIndicator = find.byKey(
      const ValueKey('AikoNavIndicator_/accounts'),
    );
    final homeIndicator = find.byKey(const ValueKey('AikoNavIndicator_/home'));

    expect(tester.getSize(accountsIndicator).width, 0);
    expect(tester.getSize(accountsIndicator).height, 3);
    expect(tester.getSize(homeIndicator).width, 32);
  });

  testWidgets('tab tap targets are at least 48dp tall', (tester) async {
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

    for (final label in [
      'Accounts',
      'Categories',
      'Overview',
      'Transactions',
      'Aiko',
    ]) {
      final cell = find.byTooltip(label);
      expect(cell, findsOneWidget, reason: 'missing tooltip for $label');
      expect(
        tester.getRect(cell).height,
        greaterThanOrEqualTo(48),
        reason: '$label tap target too short',
      );
    }
  });
}
