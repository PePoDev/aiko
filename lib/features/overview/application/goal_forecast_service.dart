import '../../../core/prediction/monte_carlo_engine.dart';
import '../../accounts/domain/account.dart';

class GoalForecast {
  const GoalForecast({
    required this.monthlyContribution,
    required this.months,
    required this.result,
  });

  final double monthlyContribution;
  final int months;
  final MonteCarloSimulationResult result;
}

/// Monte Carlo goal forecast derived from a real goal account. Single source of
/// truth for the dashboard Goal Simulator card and the Chance of Success
/// screen, so both show identical assumptions. Pure function object.
class GoalForecastService {
  const GoalForecastService({this.engine = const MonteCarloEngine()});

  final MonteCarloEngine engine;

  /// Whole months from [asOf] to the goal's target date; at least 1. Falls back
  /// to a one-year horizon when the goal has no target date.
  int monthsUntilTarget(Account goal, DateTime asOf) {
    final target = goal.targetDate ?? asOf.add(const Duration(days: 365));
    final months = ((target.year - asOf.year) * 12) + target.month - asOf.month;
    return months <= 0 ? 1 : months;
  }

  /// Even monthly saving needed to cover the remaining gap by the target date.
  /// Defaults to 100 when the goal is already met (so the simulation still
  /// runs) — mirrors the dashboard's prior inline logic.
  double monthlyContribution(Account goal, DateTime asOf) {
    final months = monthsUntilTarget(goal, asOf);
    final contribution = goal.goalRemaining.amount.toDouble() / months;
    return contribution <= 0 ? 100.0 : contribution;
  }

  GoalForecast forecast(Account goal, {DateTime? asOf}) {
    final now = asOf ?? DateTime.now();
    final months = monthsUntilTarget(goal, now);
    final contribution = monthlyContribution(goal, now);
    final result = engine.run(
      currentBalance: goal.currentBalance.amount.toDouble(),
      monthlyContribution: contribution,
      targetAmount: goal.targetAmount?.amount.toDouble() ?? 1,
      targetMonths: months,
      expectedAnnualReturnPercent: 6.0,
      annualVolatilityPercent: 12.0,
    );
    return GoalForecast(
      monthlyContribution: contribution,
      months: months,
      result: result,
    );
  }
}
