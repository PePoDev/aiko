import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/goals/application/saving_plan_service.dart';
import 'package:aiko/features/goals/domain/goal.dart';
import 'package:aiko/features/goals/domain/saving_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('saving plan links to goal and frequency', () {
    final goal = Goal(
      id: 'g1',
      userId: 'user',
      name: 'Emergency',
      purpose: GoalPurpose.emergencyFund,
      targetAmount: Money.parse('1000', 'USD'),
      currentAmount: Money.parse('500', 'USD'),
      targetDate: DateTime(2026, 6),
    );
    final plan = const SavingPlanService().createPlan(
      goal,
      ContributionFrequency.monthly,
      DateTime(2026, 1),
    );

    expect(plan.goalId, goal.id);
    expect(plan.requiredContribution.isPositive, isTrue);
  });
}
