import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/bills/domain/bill_subscription.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calculates annualized subscription cost', () {
    final bill = BillSubscription(
      merchant: 'Streaming',
      amount: Money.parse('15', 'USD'),
      billingCycle: BillingCycle.monthly,
      nextBillingDate: DateTime.utc(2026, 6),
    );

    expect(bill.annualizedCost, 180);
  });

  test('detects due bills inside reminder window', () {
    final bill = BillSubscription(
      merchant: 'Internet',
      amount: Money.parse('80', 'USD'),
      billingCycle: BillingCycle.monthly,
      nextBillingDate: DateTime.utc(2026, 5, 22),
    );

    expect(
      bill.isDueWithin(DateTime.utc(2026, 5, 19), const Duration(days: 3)),
      isTrue,
    );
  });
}
