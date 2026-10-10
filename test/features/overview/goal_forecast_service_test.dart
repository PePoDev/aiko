import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/overview/application/goal_forecast_service.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = GoalForecastService();
  final asOf = DateTime(2026, 1, 15, 10);

  Account goal({
    String current = '0',
    String? target = '1000',
    DateTime? targetDate,
    String id = 'g',
  }) => Account(
    id: id,
    userId: 'u',
    name: 'Emergency Fund',
    type: AccountType.goal,
    currentBalance: Money.parse(current, 'USD'),
    targetAmount: target == null ? null : Money.parse(target, 'USD'),
    targetDate: targetDate,
  );

  var seq = 0;
  FinanceTransaction tx(
    String amount,
    DateTime date, {
    TransactionType type = TransactionType.transferIn,
    String accountId = 'g',
    String currency = 'USD',
    TransactionStatus status = TransactionStatus.posted,
  }) => FinanceTransaction(
    id: 't${seq++}',
    userId: 'u',
    accountId: accountId,
    type: type,
    amount: Money.parse(amount, currency),
    date: date,
    status: status,
  );

  group('blockerFor', () {
    test('needs a target amount and a target date', () {
      expect(
        service.blockerFor(goal(target: null), asOf),
        GoalForecastBlocker.missingTargetAndDate,
      );
      expect(
        service.blockerFor(
          goal(target: null, targetDate: DateTime(2026, 7, 1)),
          asOf,
        ),
        GoalForecastBlocker.missingTarget,
      );
      expect(
        service.blockerFor(
          goal(target: '0', targetDate: DateTime(2026, 7)),
          asOf,
        ),
        GoalForecastBlocker.missingTarget,
      );
      expect(
        service.blockerFor(goal(), asOf),
        GoalForecastBlocker.missingTargetDate,
      );
    });

    test('a past target date blocks; today still counts', () {
      expect(
        service.blockerFor(goal(targetDate: DateTime(2026, 1, 14)), asOf),
        GoalForecastBlocker.targetDatePassed,
      );
      expect(
        service.blockerFor(goal(targetDate: DateTime(2026, 1, 15)), asOf),
        isNull,
      );
    });

    test('evaluate returns the blocker instead of simulating', () {
      final outcome = service.evaluate(goal(), const [], asOf: asOf);
      expect(outcome.blocker, GoalForecastBlocker.missingTargetDate);
      expect(outcome.forecast, isNull);
    });
  });

  test('months until target counts whole calendar months, min 1', () {
    expect(
      service.monthsUntilTarget(goal(targetDate: DateTime(2026, 7, 1)), asOf),
      6,
    );
    expect(
      service.monthsUntilTarget(goal(targetDate: DateTime(2026, 1, 31)), asOf),
      1,
    );
  });

  group('monthlyContribution (average monthly net deposit)', () {
    test('averages deposits over the current month and the five before', () {
      final g = goal(targetDate: DateTime(2026, 12, 1));
      final c = service.monthlyContribution(g, [
        tx('100', DateTime(2025, 6, 1)), // before the window: ignored
        tx('300', DateTime(2025, 8, 5)),
        tx('300', DateTime(2025, 10, 5)),
        tx('300', DateTime(2025, 12, 5)),
        tx('300', DateTime(2026, 1, 5)),
      ], asOf);
      // Aug 2025 – Jan 2026: 1,200 over 6 months.
      expect(c, closeTo(200, 0.001));
    });

    test('withdrawals and expenses on the goal reduce the deposits', () {
      final g = goal(targetDate: DateTime(2026, 12, 1));
      final c = service.monthlyContribution(g, [
        tx('600', DateTime(2025, 8, 1)),
        tx('900', DateTime(2025, 9, 1), type: TransactionType.income),
        tx('300', DateTime(2025, 10, 1), type: TransactionType.transferOut),
      ], asOf);
      expect(c, closeTo(200, 0.001)); // (600 + 900 − 300) ÷ 6
    });

    test('a new goal averages from its first month, not the full window', () {
      final g = goal(targetDate: DateTime(2026, 12, 1));
      final c = service.monthlyContribution(g, [
        tx('400', DateTime(2025, 12, 20)),
        tx('200', DateTime(2026, 1, 10)),
      ], asOf);
      expect(c, closeTo(300, 0.001)); // 600 over Dec and Jan
    });

    test('ignores other accounts, other currencies, voided, archived and '
        'future-dated rows', () {
      final g = goal(targetDate: DateTime(2026, 12, 1));
      final c = service.monthlyContribution(g, [
        tx('500', DateTime(2026, 1, 2)),
        tx('999', DateTime(2026, 1, 2), accountId: 'other'),
        tx('999', DateTime(2026, 1, 2), currency: 'THB'),
        tx('999', DateTime(2026, 1, 2), status: TransactionStatus.voided),
        tx('999', DateTime(2026, 1, 2), status: TransactionStatus.archived),
        tx('999', DateTime(2026, 1, 16)),
      ], asOf);
      expect(c, closeTo(500, 0.001));
    });

    test('no deposits, or net withdrawals, count as no saving', () {
      final g = goal(targetDate: DateTime(2026, 12, 1));
      expect(service.monthlyContribution(g, const [], asOf), 0);
      expect(
        service.monthlyContribution(g, [
          tx('300', DateTime(2026, 1, 2), type: TransactionType.transferOut),
        ], asOf),
        0,
      );
    });
  });

  test('forecast uses the deposit average and returns a probability', () {
    final forecast = service.forecast(
      goal(current: '500', targetDate: DateTime(2026, 7, 1)),
      [tx('100', DateTime(2026, 1, 3))],
      asOf: asOf,
    );
    expect(forecast.months, 6);
    expect(forecast.monthlyContribution, closeTo(100, 0.001));
    expect(forecast.result.successProbabilityPercent, inInclusiveRange(0, 100));
    expect(
      forecast.result.conservativeAmount,
      lessThanOrEqualTo(forecast.result.expectedAmount),
    );
    expect(
      forecast.result.expectedAmount,
      lessThanOrEqualTo(forecast.result.optimisticAmount),
    );
  });

  test('a goal already at its target is certain', () {
    final forecast = service.forecast(
      goal(current: '1200', targetDate: DateTime(2026, 7, 1)),
      const [],
      asOf: asOf,
    );
    expect(forecast.result.successProbabilityPercent, 100);
  });
}
