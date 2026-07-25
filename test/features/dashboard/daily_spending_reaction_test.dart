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
}
