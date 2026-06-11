import 'package:aiko/features/assets/presentation/assets_net_worth_screen.dart';
import 'package:aiko/features/portfolio/presentation/portfolio_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('portfolio screen shows a simple holdings overview', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: PortfolioScreen())),
    );

    expect(find.text('Portfolio'), findsOneWidget);
    expect(find.text('Portfolio value'), findsOneWidget);
    expect(find.text('Holdings'), findsOneWidget);
    expect(find.text('Allocation'), findsOneWidget);
    expect(find.text('Add holding'), findsOneWidget);
    expect(find.text('Capital Gains Tax Estimator'), findsNothing);
    expect(find.textContaining('real-time'), findsNothing);
  });

  testWidgets('portfolio search filters holdings by symbol', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: PortfolioScreen())),
    );

    await tester.tap(find.byTooltip('Search holdings'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'BND');
    await tester.pump();

    expect(
      find.descendant(of: find.byType(Card), matching: find.text('BND')),
      findsOneWidget,
    );
    expect(find.text('VTI'), findsNothing);
  });

  testWidgets('assets screen exposes core sections', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AssetsNetWorthScreen())),
    );

    expect(find.text('Net worth'), findsOneWidget);
  });
}
