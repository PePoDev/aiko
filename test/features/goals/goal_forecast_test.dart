import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/goals/application/goal_forecast_service.dart';
import 'package:aiko/features/goals/domain/goal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('goal forecast computes monthly contribution', () {
    final goal = Goal(
      id: 'g1',
      userId: 'user',
      name: 'Emergency',
      purpose: GoalPurpose.emergencyFund,
      targetAmount: Money.parse('1200', 'USD'),
      currentAmount: Money.zero('USD'),
      targetDate: DateTime(2026, 7),
    );
    final contribution = const GoalForecastService()
        .requiredMonthlyContribution(goal, DateTime(2026, 1));

    expect(contribution.amount.toString(), startsWith('200'));
  });
}
