import 'package:aiko/shared/widgets/finance_card.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('finance card uses stable product UI tap treatment', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AikoTheme.light(),
        home: Scaffold(
          body: FinanceCard(
            title: 'Balance',
            onTap: () {},
            child: const Text('THB 1,200'),
          ),
        ),
      ),
    );

    expect(find.byType(AnimatedScale), findsNothing);
    expect(find.byType(AnimatedContainer), findsNothing);
    expect(find.byType(InkWell), findsOneWidget);
  });

  testWidgets('finance card uses 8px card radius from the design system', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AikoTheme.light(),
        home: const Scaffold(
          body: FinanceCard(title: 'Budget', child: Text('On track')),
        ),
      ),
    );

    final card = tester.widget<Card>(find.byType(Card));
    final shape = card.shape;

    expect(shape, isA<RoundedRectangleBorder>());
    expect(
      (shape! as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(8),
    );
  });

  testWidgets('finance card only exposes tap semantics when tappable', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: AikoTheme.light(),
          home: Scaffold(
            body: Column(
              children: [
                const FinanceCard(title: 'Static', child: Text('Read only')),
                FinanceCard(
                  title: 'Open',
                  onTap: () {},
                  child: const Text('Details'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.text('Static')),
        isNot(matchesSemantics(hasTapAction: true)),
      );
      expect(
        tester.getSemantics(find.text('Open')),
        matchesSemantics(
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
    } finally {
      handle.dispose();
    }
  });
}
