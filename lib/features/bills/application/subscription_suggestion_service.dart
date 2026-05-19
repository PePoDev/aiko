import '../domain/bill_subscription.dart';

class SubscriptionSuggestion {
  const SubscriptionSuggestion({
    required this.merchant,
    required this.message,
    required this.estimatedAnnualSavings,
  });

  final String merchant;
  final String message;
  final double estimatedAnnualSavings;
}

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
          ),
        )
        .toList(growable: false);
  }
}
