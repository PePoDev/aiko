import 'package:aiko/app/providers.dart';
import 'package:aiko/features/insights/domain/aiko_insight.dart';
import 'package:aiko/features/insights/presentation/insights_screen.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('insights screen shows Aiko insight and review entry', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aikoInsightsProvider.overrideWith(
            (ref) async => const [
              AikoInsight(
                id: 'food-up',
                userId: 'user',
                type: AikoInsightType.diagnostic,
                title: 'Food spending increased',
                description:
                    'Food spending increased from real transaction data.',
                recommendation: 'Review recent dining transactions.',
                confidenceScore: 0.82,
                sourceDataSummary: ['transactions'],
              ),
            ],
          ),
        ],
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const InsightsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Food spending increased'), findsOneWidget);
    expect(find.text('Aiko Review'), findsOneWidget);
  });
}
