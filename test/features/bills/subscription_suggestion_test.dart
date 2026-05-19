import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/bills/application/subscription_suggestion_service.dart';
import 'package:aiko/features/bills/domain/bill_subscription.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('suggests cancellation review for high annualized subscriptions', () {
    final suggestions = const SubscriptionSuggestionService()
        .cancellationCandidates([
          BillSubscription(
            merchant: 'Streaming',
            amount: Money.parse('20', 'USD'),
            billingCycle: BillingCycle.monthly,
            nextBillingDate: DateTime.utc(2026, 6),
          ),
        ]);

    expect(suggestions.single.estimatedAnnualSavings, 240);
    expect(suggestions.single.message, contains('Review Streaming'));
  });
}
