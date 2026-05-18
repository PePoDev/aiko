import '../../../core/money/money.dart';
import '../domain/goal.dart';

class GoalForecastService {
  const GoalForecastService();

  Money requiredMonthlyContribution(Goal goal, DateTime today) {
    final remainingMonths = _remainingMonths(today, goal.targetDate);
    if (remainingMonths <= 0) {
      return goal.remaining;
    }
    return goal.remaining.dividedByInt(remainingMonths);
  }

  bool isImpossibleWith(Goal goal, Money monthlyLeftover, DateTime today) {
    return requiredMonthlyContribution(goal, today).compareTo(monthlyLeftover) >
        0;
  }

  int _remainingMonths(DateTime from, DateTime to) {
    final months = (to.year - from.year) * 12 + to.month - from.month;
    return months <= 0 ? 0 : months;
  }
}
