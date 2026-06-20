import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/overview/application/goal_forecast_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = GoalForecastService();
  final asOf = DateTime(2026, 1, 1);

  Account goal({
    required String current,
    required String target,
    DateTime? targetDate,
  }) => Account(
    id: 'g',
    userId: 'u',
    name: 'Emergency Fund',
    type: AccountType.goal,
    currentBalance: Money.parse(current, 'USD'),
    targetAmount: Money.parse(target, 'USD'),
    targetDate: targetDate,
  );

  test('months until target counts whole calendar months, min 1', () {
    expect(
      service.monthsUntilTarget(
        goal(current: '0', target: '1000', targetDate: DateTime(2026, 7, 1)),
        asOf,
      ),
      6,
    );
    // Past/!set date floors at 1.
    expect(
      service.monthsUntilTarget(
        goal(current: '0', target: '1000', targetDate: DateTime(2025, 1, 1)),
        asOf,
      ),
      1,
    );
  });

  test('monthly contribution spreads the remaining gap over the horizon', () {
    final c = service.monthlyContribution(
      goal(current: '400', target: '1000', targetDate: DateTime(2026, 7, 1)),
      asOf,
    );
    expect(c, closeTo(100, 0.001)); // 600 remaining / 6 months
  });

  test('already-met goal still simulates with a default contribution', () {
    final c = service.monthlyContribution(
      goal(current: '2000', target: '1000', targetDate: DateTime(2026, 7, 1)),
      asOf,
    );
    expect(c, 100.0);
  });

  test('forecast returns a probability in 0..100 with band ordering', () {
    final forecast = service.forecast(
      goal(current: '500', target: '1000', targetDate: DateTime(2026, 7, 1)),
      asOf: asOf,
    );
    expect(forecast.months, 6);
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
}
