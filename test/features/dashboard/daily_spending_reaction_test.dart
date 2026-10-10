import 'package:aiko/features/dashboard/domain/daily_spending_reaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DailySpendingReaction.fromRatio', () {
    test('is comfortable below 75 percent', () {
      expect(
        DailySpendingReaction.fromRatio(0.749),
        DailySpendingReaction.comfortable,
      );
    });

    test('is caution from 75 percent until the safe amount is used', () {
      expect(
        DailySpendingReaction.fromRatio(0.75),
        DailySpendingReaction.caution,
      );
      expect(
        DailySpendingReaction.fromRatio(0.999),
        DailySpendingReaction.caution,
      );
    });

    test('is exceeded from 100 percent onward', () {
      expect(
        DailySpendingReaction.fromRatio(1),
        DailySpendingReaction.exceeded,
      );
      expect(
        DailySpendingReaction.fromRatio(1.2),
        DailySpendingReaction.exceeded,
      );
    });
  });

  group('assessDailySpending', () {
    test('measures today against the daily safe amount', () {
      final result = assessDailySpending(
        spentToday: 80,
        dailySafe: 100,
        hasIncomeThisMonth: true,
      );
      expect(result.reaction, DailySpendingReaction.caution);
      expect(result.ratio, closeTo(0.8, 1e-9));
    });

    test('nothing safe to spend and something spent today is exceeded', () {
      final result = assessDailySpending(
        spentToday: 12,
        dailySafe: 0,
        hasIncomeThisMonth: true,
      );
      expect(result.reaction, DailySpendingReaction.exceeded);
      expect(result.ratio, 1);
    });

    test(
      'nothing safe to spend and nothing spent is idle, not comfortable',
      () {
        final result = assessDailySpending(
          spentToday: 0,
          dailySafe: 0,
          hasIncomeThisMonth: true,
        );
        expect(result.reaction, DailySpendingReaction.idle);
        expect(result.ratio, 0);
      },
    );

    test('no income this month asks for income first', () {
      for (final spent in [0.0, 25.0]) {
        final result = assessDailySpending(
          spentToday: spent,
          dailySafe: 0,
          hasIncomeThisMonth: false,
        );
        expect(result.reaction, DailySpendingReaction.needsIncome);
        expect(result.ratio, 0);
      }
    });
  });
}
