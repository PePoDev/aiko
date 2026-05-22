import '../../../core/monetization/feature_entitlement.dart';

class PurchaseQuote {
  const PurchaseQuote({
    required this.plan,
    required this.storeProductId,
    required this.displayPrice,
    required this.upgradeAvailable,
  });

  final PlanTier plan;
  final String storeProductId;
  final String displayPrice;
  final bool upgradeAvailable;
}

class InAppBillingService {
  const InAppBillingService();

  List<PurchaseQuote> availableUpgrades(PlanTier currentTier) {
    return PlanTier.values
        .where((tier) => tier.index > currentTier.index)
        .map(_quoteFor)
        .toList(growable: false);
  }

  PurchaseQuote _quoteFor(PlanTier tier) {
    return switch (tier) {
      PlanTier.free => const PurchaseQuote(
        plan: PlanTier.free,
        storeProductId: 'aiko.free',
        displayPrice: '\$0',
        upgradeAvailable: false,
      ),
      PlanTier.premium => const PurchaseQuote(
        plan: PlanTier.premium,
        storeProductId: 'aiko.premium.monthly',
        displayPrice: '\$7.99/mo',
        upgradeAvailable: true,
      ),
      PlanTier.pro => const PurchaseQuote(
        plan: PlanTier.pro,
        storeProductId: 'aiko.pro.monthly',
        displayPrice: '\$14.99/mo',
        upgradeAvailable: true,
      ),
    };
  }
}
