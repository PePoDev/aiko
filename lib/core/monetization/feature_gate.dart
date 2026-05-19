import 'feature_entitlement.dart';

class FeatureGate {
  const FeatureGate({required this.featureKey, required this.requiredTier});

  final String featureKey;
  final PlanTier requiredTier;

  bool isLockedFor(PlanTier tier) => tier.index < requiredTier.index;
}
