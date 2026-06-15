import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/insights/application/aiko_insight_service.dart';
import 'package:aiko/features/insights/domain/aiko_insight.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = AikoInsightService();

  group('AikoInsightService.budgetThreshold', () {
    test('title reports the percent used and uses the category name', () {
      final insight = service.budgetThreshold(
        userId: 'u1',
        categoryName: 'Groceries',
        percentUsed: 87.4,
        dailyLimit: Money.parse('25', 'USD'),
      );
      expect(insight.title, 'Groceries budget is 87% used');
      expect(insight.type, AikoInsightType.prescriptive);
    });

    test('recommendation includes the formatted daily limit', () {
      final insight = service.budgetThreshold(
        userId: 'u1',
        categoryName: 'Dining',
        percentUsed: 50,
        dailyLimit: Money.parse('15', 'USD'),
      );
      expect(insight.recommendation, contains('Dining'));
      expect(insight.recommendation, contains(r'$'));
    });
  });

  group('AikoInsightService.monthlyReview', () {
    test('flags a negative leftover with a cash-flow recommendation', () {
      final insight = service.monthlyReview(
        userId: 'u1',
        monthLabel: '2026-05',
        income: Money.parse('3000', 'USD'),
        expenses: Money.parse('2700', 'USD'),
        savings: Money.parse('500', 'USD'),
        topCategoryName: 'Rent',
      );
      expect(insight.type, AikoInsightType.diagnostic);
      expect(insight.title, '2026-05 money review');
      expect(insight.recommendation, contains('Rent'));
    });

    test('celebrates a positive leftover with a savings recommendation', () {
      final insight = service.monthlyReview(
        userId: 'u1',
        monthLabel: '2026-05',
        income: Money.parse('4000', 'USD'),
        expenses: Money.parse('2500', 'USD'),
        savings: Money.parse('500', 'USD'),
        topCategoryName: 'Groceries',
      );
      expect(insight.recommendation, contains('cushion'));
    });
  });
}
