import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/insights/application/aiko_insight_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('insight includes source summary and recommendation', () {
    final insight = const AikoInsightService().budgetThreshold(
      userId: 'user',
      categoryName: 'Dining',
      percentUsed: 78,
      dailyLimit: Money.parse('12', 'USD'),
    );

    expect(insight.sourceDataSummary, contains('budget'));
    expect(insight.recommendation, contains('Dining'));
  });
}
