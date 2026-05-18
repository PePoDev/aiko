import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/dashboard/application/dashboard_summary_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('leftover subtracts reserved money and spending', () {
    const service = DashboardSummaryService();
    final leftover = service.leftover(
      income: Money.parse('1000', 'USD'),
      fixedBills: Money.parse('300', 'USD'),
      requiredExpenses: Money.parse('100', 'USD'),
      debtPayments: Money.parse('50', 'USD'),
      goalContributions: Money.parse('100', 'USD'),
      currentSpending: Money.parse('200', 'USD'),
    );

    expect(leftover.amount.toString(), '250');
  });

  test('pace identifies fast spending', () {
    const service = DashboardSummaryService();
    final pace = service.pace(
      Money.parse('700', 'USD'),
      Money.parse('1000', 'USD'),
      0.5,
    );

    expect(pace.isFast, isTrue);
  });
}
