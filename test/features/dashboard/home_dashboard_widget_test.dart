import 'package:aiko/features/dashboard/presentation/home_dashboard_screen.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('home dashboard shows safe-to-spend and Aiko welcome', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
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
      ProviderScope(
        child: MaterialApp(
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
      ProviderScope(
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const HomeDashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Quick add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transaction'));
    await tester.pumpAndSettle();

    expect(find.text('Add transaction'), findsOneWidget);
    expect(find.text('Amount'), findsOneWidget);
  });

  testWidgets('quick add budget opens the budget form directly', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
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
    expect(find.text('Save budget'), findsOneWidget);
  });
}
