import 'package:aiko/core/money/money.dart';
import 'package:aiko/core/notifications/notification_policy_service.dart';
import 'package:aiko/core/notifications/notification_schedule.dart';
import 'package:aiko/features/bills/application/subscription_suggestion_service.dart';
import 'package:aiko/features/bills/domain/bill_subscription.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('bill due reminder and subscription review flow', (tester) async {
    final bill = BillSubscription(
      merchant: 'Internet',
      amount: Money.parse('90', 'USD'),
      billingCycle: BillingCycle.monthly,
      nextBillingDate: DateTime.utc(2026, 5, 22),
    );
    const schedule = NotificationSchedule(
      type: 'billDue',
      timing: NotificationTiming.threeDaysBefore,
      permissionState: NotificationPermissionState.granted,
    );

    final scheduledAt = const NotificationPolicyService().scheduledAt(
      bill.nextBillingDate,
      schedule,
    );
    final suggestions = const SubscriptionSuggestionService()
        .cancellationCandidates([bill]);

    expect(scheduledAt, DateTime.utc(2026, 5, 19));
    expect(suggestions.single.estimatedAnnualSavings, 1080);
  });
}
