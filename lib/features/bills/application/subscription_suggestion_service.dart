import '../domain/bill_subscription.dart';

class SubscriptionSuggestion {
  const SubscriptionSuggestion({
    required this.merchant,
    required this.message,
    required this.estimatedAnnualSavings,
    this.cancelGuide = const [],
    this.alertType = SubscriptionAlertType.review,
  });

  final String merchant;
  final String message;
  final double estimatedAnnualSavings;
  final List<String> cancelGuide;
  final SubscriptionAlertType alertType;
}

enum SubscriptionAlertType { review, priceIncrease, trialEnding }

class SubscriptionSuggestionService {
  const SubscriptionSuggestionService();

  List<SubscriptionSuggestion> cancellationCandidates(
    List<BillSubscription> bills,
  ) {
    return bills
        .where((bill) => bill.annualizedCost >= 120)
        .map(
          (bill) => SubscriptionSuggestion(
            merchant: bill.merchant,
            message: 'Review ${bill.merchant} before the next renewal.',
            estimatedAnnualSavings: bill.annualizedCost,
            cancelGuide: cancellationGuide(bill.merchant),
          ),
        )
        .toList(growable: false);
  }

  List<SubscriptionSuggestion> priceChangeAlerts({
    required List<BillSubscription> currentBills,
    required List<BillSubscription> previousBills,
    double thresholdPercent = 10,
  }) {
    final previousByMerchant = {
      for (final bill in previousBills) bill.merchant.toLowerCase(): bill,
    };
    final alerts = <SubscriptionSuggestion>[];
    for (final current in currentBills) {
      final previous = previousByMerchant[current.merchant.toLowerCase()];
      if (previous == null) {
        continue;
      }
      final oldCost = previous.annualizedCost;
      if (oldCost <= 0) {
        continue;
      }
      final changePercent = (current.annualizedCost - oldCost) / oldCost * 100;
      if (changePercent >= thresholdPercent) {
        alerts.add(
          SubscriptionSuggestion(
            merchant: current.merchant,
            message:
                '${current.merchant} increased by ${changePercent.toStringAsFixed(0)}%.',
            estimatedAnnualSavings: current.annualizedCost,
            alertType: SubscriptionAlertType.priceIncrease,
            cancelGuide: cancellationGuide(current.merchant),
          ),
        );
      }
    }
    return alerts;
  }

  List<SubscriptionSuggestion> trialEndingAlerts(
    List<BillSubscription> bills, {
    required DateTime now,
    Duration window = const Duration(days: 7),
  }) {
    return bills
        .where((bill) => bill.isDueWithin(now, window))
        .where(
          (bill) => RegExp(
            'trial|intro',
            caseSensitive: false,
          ).hasMatch('${bill.merchant} ${bill.categoryId ?? ''}'),
        )
        .map(
          (bill) => SubscriptionSuggestion(
            merchant: bill.merchant,
            message: '${bill.merchant} trial may renew within 7 days.',
            estimatedAnnualSavings: bill.annualizedCost,
            alertType: SubscriptionAlertType.trialEnding,
            cancelGuide: cancellationGuide(bill.merchant),
          ),
        )
        .toList(growable: false);
  }

  List<String> cancellationGuide(String merchant) {
    return [
      'Open $merchant account settings.',
      'Find plan, billing, or subscription management.',
      'Choose cancel or turn off auto-renewal.',
      'Save the confirmation email or screenshot in Aiko.',
    ];
  }
}
