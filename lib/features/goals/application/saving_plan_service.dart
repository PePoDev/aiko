import '../domain/goal.dart';
import '../domain/saving_plan.dart';

class SavingPlanService {
  const SavingPlanService();

  SavingPlan createPlan(
    Goal goal,
    ContributionFrequency frequency,
    DateTime today,
  ) {
    final periods = _periods(today, goal.targetDate, frequency);
    final contribution = periods <= 0
        ? goal.remaining
        : goal.remaining.dividedByInt(periods);
    return SavingPlan(
      id: '${goal.id}-plan',
      userId: goal.userId,
      goalId: goal.id,
      frequency: frequency,
      requiredContribution: contribution,
      forecastedCompletionDate: goal.targetDate,
    );
  }

  int _periods(DateTime from, DateTime to, ContributionFrequency frequency) {
    final days = to.difference(from).inDays;
    if (days <= 0) {
      return 0;
    }
    return frequency == ContributionFrequency.weekly
        ? (days / 7).ceil()
        : (days / 30).ceil();
  }
}
