import 'package:aiko/features/assets/presentation/assets_net_worth_screen.dart';
import 'package:aiko/features/portfolio/presentation/portfolio_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('portfolio and assets screens expose core sections', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PortfolioScreen()));
    expect(find.text('Holdings'), findsOneWidget);
    await tester.pumpWidget(const MaterialApp(home: AssetsNetWorthScreen()));
    expect(find.text('Net worth'), findsOneWidget);
  });
}
