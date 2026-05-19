import 'package:aiko/core/monetization/entitlement_service.dart';
import 'package:aiko/core/monetization/feature_entitlement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('allows a plan tier when it meets the required tier', () {
    const entitlement = FeatureEntitlement(
      featureKey: 'portfolioAnalytics',
      requiredTier: PlanTier.premium,
    );

    expect(entitlement.allows(PlanTier.free), isFalse);
    expect(entitlement.allows(PlanTier.premium), isTrue);
    expect(entitlement.allows(PlanTier.pro), isTrue);
  });

  test('shows premium gate for lower tiers', () {
    const gate = PremiumGate(
      featureKey: 'taxReports',
      message: 'Tax reports are included in Premium.',
      requiredTier: PlanTier.premium,
    );

    expect(gate.shouldShowFor(PlanTier.free), isTrue);
    expect(gate.shouldShowFor(PlanTier.pro), isFalse);
  });

  test('entitlement service applies safe gating', () {
    const entitlement = FeatureEntitlement(
      featureKey: 'portfolio',
      requiredTier: PlanTier.premium,
    );

    expect(
      const EntitlementService().canUse(entitlement, PlanTier.free),
      isFalse,
    );
  });
}
