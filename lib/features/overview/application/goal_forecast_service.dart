import 'package:decimal/decimal.dart';

import '../../../core/money/money.dart';
import '../../../core/prediction/monte_carlo_engine.dart';
import '../../accounts/domain/account.dart';
import '../../transactions/domain/transaction.dart';

/// Why a goal can't be forecast yet.
enum GoalForecastBlocker {
  missingTarget,
  missingTargetDate,
  missingTargetAndDate,
  targetDatePassed,
}

class GoalForecast {
  const GoalForecast({
    required this.monthlyContribution,
    required this.months,
    required this.result,
  });

  /// The goal's recent average monthly net deposit (see
  /// [GoalForecastService.contributionWindowMonths]), never negative.
  final double monthlyContribution;
  final int months;
  final MonteCarloSimulationResult result;
}

/// A goal and either its forecast or why it can't be forecast yet.
class GoalForecastOutcome {
  const GoalForecastOutcome.blocked(this.goal, GoalForecastBlocker this.blocker)
    : forecast = null;

  const GoalForecastOutcome.ready(this.goal, GoalForecast this.forecast)
    : blocker = null;

  final Account goal;
  final GoalForecastBlocker? blocker;
  final GoalForecast? forecast;
}

/// Monte Carlo goal forecast derived from a real goal account and its
/// transactions. Single source of truth for `goalForecastProvider` and the
/// Chance of Success screen, so every forecast uses the same assumptions.
/// Pure function object.
class GoalForecastService {
  const GoalForecastService({this.engine = const MonteCarloEngine()});

  final MonteCarloEngine engine;

  /// How far back [monthlyContribution] looks: the current calendar month and
  /// the five before it.
  static const contributionWindowMonths = 6;

  /// What stops [goal] from being forecast on [asOf], or null when it can be:
  /// it needs a positive target amount and a target date that hasn't passed.
  GoalForecastBlocker? blockerFor(Account goal, DateTime asOf) {
    final target = goal.targetAmount;
    final hasTarget = target != null && target.isPositive;
    final targetDate = goal.targetDate;
    if (!hasTarget && targetDate == null) {
      return GoalForecastBlocker.missingTargetAndDate;
    }
    if (!hasTarget) return GoalForecastBlocker.missingTarget;
    if (targetDate == null) return GoalForecastBlocker.missingTargetDate;
    final today = DateTime(asOf.year, asOf.month, asOf.day);
    final targetDay = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
    );
    if (targetDay.isBefore(today)) return GoalForecastBlocker.targetDatePassed;
    return null;
  }

  /// Whole calendar months from [asOf] to the goal's target date; at least 1
  /// (a target later this month still gets one month).
  int monthsUntilTarget(Account goal, DateTime asOf) {
    final target = goal.targetDate ?? asOf;
    final months = ((target.year - asOf.year) * 12) + target.month - asOf.month;
    return months <= 0 ? 1 : months;
  }

  /// The goal account's average monthly net deposit: deposits minus
  /// withdrawals on [goal] (as they move its balance) dated from the start of
  /// the month [contributionWindowMonths] − 1 months before [asOf] through
  /// [asOf], divided by the months in that window. A goal whose first
  /// transaction is more recent than the window start is averaged from that
  /// transaction's month, so a new goal isn't diluted by months it didn't
  /// exist. Voided and archived transactions, and amounts in another currency
  /// than the goal, are ignored. Never negative: net withdrawals count as no
  /// saving.
  double monthlyContribution(
    Account goal,
    List<FinanceTransaction> transactions,
    DateTime asOf,
  ) {
    final currency = goal.currentBalance.currency;
    final endExclusive = DateTime(asOf.year, asOf.month, asOf.day + 1);
    var windowStart = DateTime(
      asOf.year,
      asOf.month - (contributionWindowMonths - 1),
    );

    final relevant = [
      for (final tx in transactions)
        if (tx.accountId == goal.id &&
            tx.amount.currency == currency &&
            tx.status != TransactionStatus.voided &&
            tx.status != TransactionStatus.archived &&
            tx.date.isBefore(endExclusive))
          tx,
    ];
    if (relevant.isEmpty) return 0;

    final first = relevant
        .map((tx) => tx.date)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final firstMonth = DateTime(first.year, first.month);
    if (firstMonth.isAfter(windowStart)) windowStart = firstMonth;

    var net = Decimal.zero;
    for (final tx in relevant) {
      if (tx.date.isBefore(windowStart)) continue;
      // Same sign rule as the balance: deposits add, withdrawals subtract.
      net += tx.applyToAccountBalance(Money.zero(currency)).amount;
    }
    final months =
        (asOf.year - windowStart.year) * 12 +
        asOf.month -
        windowStart.month +
        1;
    final average = net.toDouble() / months;
    return average > 0 ? average : 0;
  }

  /// [goal]'s forecast, or the [GoalForecastBlocker] that prevents one.
  GoalForecastOutcome evaluate(
    Account goal,
    List<FinanceTransaction> transactions, {
    DateTime? asOf,
  }) {
    final now = asOf ?? DateTime.now();
    final blocker = blockerFor(goal, now);
    if (blocker != null) return GoalForecastOutcome.blocked(goal, blocker);
    return GoalForecastOutcome.ready(
      goal,
      forecast(goal, transactions, asOf: now),
    );
  }

  /// Runs the simulation for a goal with no [blockerFor]. A goal already at
  /// or above its target is certain (100%) without simulating.
  GoalForecast forecast(
    Account goal,
    List<FinanceTransaction> transactions, {
    DateTime? asOf,
  }) {
    final now = asOf ?? DateTime.now();
    assert(blockerFor(goal, now) == null, 'Goal cannot be forecast yet');
    final months = monthsUntilTarget(goal, now);
    final contribution = monthlyContribution(goal, transactions, now);
    final current = goal.currentBalance.amount.toDouble();
    final target = goal.targetAmount?.amount.toDouble() ?? 0;
    final result = current >= target
        ? const MonteCarloSimulationResult(successProbabilityPercent: 100)
        : engine.run(
            currentBalance: current,
            monthlyContribution: contribution,
            targetAmount: target,
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
