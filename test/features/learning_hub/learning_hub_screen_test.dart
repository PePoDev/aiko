import 'package:aiko/features/learning_hub/presentation/learning_hub_screen.dart';
import 'package:aiko/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpLearningHub(WidgetTester tester) {
    return tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LearningHubScreen(),
      ),
    );
  }

  testWidgets('replaces the standalone glossary with inline terms', (
    tester,
  ) async {
    await pumpLearningHub(tester);

    expect(find.text('Glossary'), findsNothing);
    expect(find.text('Safe-to-spend'), findsOneWidget);
    expect(find.text('APR'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Rebalancing').first,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Rebalancing'), findsWidgets);
  });

  testWidgets('shows a lesson term definition beside its content', (
    tester,
  ) async {
    await pumpLearningHub(tester);
    expect(find.text('Annual percentage rate.'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('APR'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.tap(find.text('APR'));
    await tester.pumpAndSettle();

    expect(find.text('Annual percentage rate.'), findsOneWidget);
  });
}
