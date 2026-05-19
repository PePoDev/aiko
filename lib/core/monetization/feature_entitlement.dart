enum PlanTier { free, premium, pro }

class FeatureEntitlement {
  const FeatureEntitlement({
    required this.featureKey,
    required this.requiredTier,
    this.enabled = true,
  });

  final String featureKey;
  final PlanTier requiredTier;
  final bool enabled;

  bool allows(PlanTier currentTier) {
    if (!enabled) {
      return false;
    }

    return currentTier.index >= requiredTier.index;
  }
}

class PremiumGate {
  const PremiumGate({
    required this.featureKey,
    required this.message,
    required this.requiredTier,
  });

  final String featureKey;
  final String message;
  final PlanTier requiredTier;

  bool shouldShowFor(PlanTier currentTier) =>
      currentTier.index < requiredTier.index;
}
