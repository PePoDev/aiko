import 'package:aiko/features/dashboard/domain/daily_spending_reaction.dart';
import 'package:aiko/features/dashboard/presentation/widgets/aiko_spending_reaction_strip.dart';
import 'package:aiko/l10n/app_localizations.dart';
import 'package:aiko/theme/aiko_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cases =
      <
        ({
          DailySpendingReaction reaction,
          Color color,
          String title,
          String message,
          String semantics,
        })
      >[
        (
          reaction: DailySpendingReaction.comfortable,
          color: AikoColors.successGreen,
          title: "You're spending comfortably",
          message: "Nice work—today's spending is in a healthy range.",
          semantics: 'Aiko is smiling',
        ),
        (
          reaction: DailySpendingReaction.caution,
          color: AikoColors.warningOrange,
          title: "You're close to today's limit",
          message: 'Aiko is a little worried—take care with the next expense.',
          semantics: 'Aiko looks worried',
        ),
        (
          reaction: DailySpendingReaction.exceeded,
          color: AikoColors.dangerRed,
          title: "Today's safe amount is used up",
          message: 'Aiko wants you to pause before spending more.',
          semantics: 'Aiko looks angry',
        ),
      ];

  for (final testCase in cases) {
    testWidgets('renders ${testCase.reaction.name} reaction', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: AikoSpendingReactionStrip(reaction: testCase.reaction),
            ),
          ),
        );

        expect(find.text(testCase.title), findsOneWidget);
        expect(find.text(testCase.message), findsOneWidget);
        expect(find.bySemanticsLabel(testCase.semantics), findsOneWidget);

        final container = tester.widget<Container>(
          find.byKey(ValueKey('aiko-reaction-${testCase.reaction.name}')),
        );
        final decoration = container.decoration! as BoxDecoration;
        expect(decoration.color, testCase.color.withValues(alpha: 0.10));
        expect(testCase.reaction.color, testCase.color);
      } finally {
        semantics.dispose();
      }
    });
  }
}
