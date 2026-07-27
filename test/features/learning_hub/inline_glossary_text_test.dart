import 'package:aiko/features/learning_hub/presentation/inline_glossary_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const glossary = <String, String>{
    'APR': 'Annual percentage rate.',
    'Compound interest': 'Interest earned on principal and prior interest.',
  };

  Widget buildSubject(String text) {
    return MaterialApp(
      home: Scaffold(
        body: InlineGlossaryText(text: text, glossary: glossary),
      ),
    );
  }

  testWidgets('matches future glossary terms case-insensitively', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        buildSubject('Learn how compound interest grows savings.'),
      );

      expect(find.text('compound interest'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'compound interest: Interest earned on principal and prior interest.',
        ),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('does not match a glossary term inside another word', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        buildSubject('APR matters, but APRIL is a month.'),
      );

      expect(
        find.bySemanticsLabel('APR: Annual percentage rate.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('APRIL is a month.', findRichText: true),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('shows the definition on tap and long press', (tester) async {
    await tester.pumpWidget(buildSubject('Compare APR before borrowing.'));

    await tester.tap(find.text('APR'));
    await tester.pumpAndSettle();
    expect(find.text('Annual percentage rate.'), findsOneWidget);

    Tooltip.dismissAllToolTips();
    await tester.pumpAndSettle();
    await tester.longPress(find.text('APR'));
    await tester.pumpAndSettle();
    expect(find.text('Annual percentage rate.'), findsOneWidget);
  });

  testWidgets('renders ordinary text unchanged', (tester) async {
    await tester.pumpWidget(buildSubject('No defined terms here.'));

    expect(
      find.text('No defined terms here.', findRichText: true),
      findsOneWidget,
    );
    expect(find.byType(Tooltip), findsNothing);
  });
}
