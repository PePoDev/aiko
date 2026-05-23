import 'package:flutter/material.dart';

import '../../../core/money/money.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';
import '../application/subscription_cancellation_service.dart';
import '../application/subscription_suggestion_service.dart';
import '../domain/bill_subscription.dart';

class BillsScreen extends StatelessWidget {
  const BillsScreen({super.key});

  static const _service = SubscriptionSuggestionService();

  void _showCancellationDialog(BuildContext context, String merchantName) {
    final nameController = TextEditingController(text: 'John Doe');
    final emailController = TextEditingController(text: 'johndoe@example.com');
    final idController = TextEditingController(text: 'SUB-123456');
    final reasonController = TextEditingController(text: 'No longer using the service.');

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Cancel $merchantName',
            style: const TextStyle(fontWeight: FontWeight.bold, color: AikoColors.deepBlue),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Aiko will generate a formal, legally structured cancellation letter and trigger the system share sheet to send it to the merchant.',
                  style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Your Full Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Your Email Address',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: idController,
                  decoration: const InputDecoration(
                    labelText: 'Account / Subscription ID',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Reason for Cancelling',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () async {
                const cancellationService = SubscriptionCancellationService();
                await cancellationService.shareCancellationLetter(
                  merchantName: merchantName,
                  subscriberName: nameController.text.trim(),
                  subscriberEmail: emailController.text.trim(),
                  accountId: idController.text.trim(),
                  cancellationReason: reasonController.text.trim(),
                );
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              icon: const Icon(Icons.share, size: 16),
              label: const Text('Generate & Share'),
              style: FilledButton.styleFrom(backgroundColor: AikoColors.deepBlue),
            ),
          ],
        );
      },
    );
  }

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
      backgroundColor: AikoColors.appBackgroundLight,
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
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
                  )) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                          Expanded(child: Text(step, style: const TextStyle(height: 1.3))),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _showCancellationDialog(context, 'Streaming Plus'),
                      icon: const Icon(Icons.mail_outline),
                      label: const Text('Generate Cancellation Email'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AikoColors.deepBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
