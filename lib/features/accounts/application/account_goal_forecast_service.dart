import '../../../core/money/money.dart';
import '../../accounts/domain/account.dart';

/// Replaces the pre-merge [GoalForecastService]. Operates on
/// [Account] rows with `type = AccountType.goal` (where [currentBalance] is
/// the saved amount and [targetAmount] / [targetDate] describe the goal).
class AccountGoalForecastService {
  const AccountGoalForecastService();

  Money requiredMonthlyContribution(Account goal, DateTime today) {
    final remainingMonths = _remainingMonths(today, goal.targetDate);
    if (remainingMonths <= 0) {
      return goal.goalRemaining;
    }
    if (goal.goalRemaining.amount <=
        Money.zero(goal.goalRemaining.currency).amount) {
      return Money.zero(goal.goalRemaining.currency);
    }
    return goal.goalRemaining.dividedByInt(remainingMonths);
  }

  bool isImpossibleWith(Account goal, Money monthlyLeftover, DateTime today) {
    return requiredMonthlyContribution(goal, today).compareTo(monthlyLeftover) >
        0;
  }

  /// Returns null when the goal already has a target date; otherwise a
  /// `yyyy-MM-dd` formatted [String] suitable for display.
  String? formattedTargetDate(Account goal) {
    final date = goal.targetDate;
    if (date == null) return null;
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  int _remainingMonths(DateTime from, DateTime? to) {
    if (to == null) return 0;
    final months = (to.year - from.year) * 12 + to.month - from.month;
    return months <= 0 ? 0 : months;
  }
}
