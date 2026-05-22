import 'package:flutter/material.dart';

import '../../../core/money/money.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';
import '../application/subscription_suggestion_service.dart';
import '../domain/bill_subscription.dart';

class BillsScreen extends StatelessWidget {
  const BillsScreen({super.key});

  static const _service = SubscriptionSuggestionService();

  @override
  Widget build(BuildContext context) {
    final current = [
      BillSubscription(
        merchant: 'Streaming Plus',
        amount: Money.parse('18', 'USD'),
        billingCycle: BillingCycle.monthly,
        nextBillingDate: DateTime(2026, 6, 1),
      ),
      BillSubscription(
        merchant: 'Cloud Trial',
        amount: Money.parse('29', 'USD'),
        billingCycle: BillingCycle.monthly,
        nextBillingDate: DateTime(2026, 5, 28),
        categoryId: 'trial',
      ),
    ];
    final previous = [
      BillSubscription(
        merchant: 'Streaming Plus',
        amount: Money.parse('14', 'USD'),
        billingCycle: BillingCycle.monthly,
        nextBillingDate: DateTime(2026, 5, 1),
      ),
    ];
    final alerts = [
      ..._service.priceChangeAlerts(
        currentBills: current,
        previousBills: previous,
      ),
      ..._service.trialEndingAlerts(current, now: DateTime(2026, 5, 22)),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Bills and Subscriptions')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FinanceCard(
              title: 'Upcoming bills',
              icon: Icons.event_available_outlined,
              accentColor: AikoColors.warningOrange,
              child: Text('Renewals and due dates appear with Aiko reminders.'),
            ),
            const SizedBox(height: 16),
            FinanceCard(
              title: 'Subscription review',
              icon: Icons.savings_outlined,
              accentColor: AikoColors.successGreen,
              child: Column(
                children: [
                  for (final alert in alerts)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(alert.merchant),
                      subtitle: Text(alert.message),
                      trailing: Text(
                        '\$${alert.estimatedAnnualSavings.round()}',
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const FinanceCard(
              title: 'Lower your bills',
              icon: Icons.savings_outlined,
              accentColor: AikoColors.successGreen,
              child: Text('Review price changes and savings opportunities.'),
            ),
            const SizedBox(height: 16),
            FinanceCard(
              title: 'Subscription cancellation assistant',
              icon: Icons.subscriptions_outlined,
              accentColor: AikoColors.deepBlue,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final step in _service.cancellationGuide(
                    'Streaming Plus',
                  ))
                    Text('- $step'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
