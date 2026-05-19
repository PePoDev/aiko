import 'feature_entitlement.dart';

class EntitlementService {
  const EntitlementService();

  bool canUse(FeatureEntitlement entitlement, PlanTier tier) {
    return entitlement.allows(tier);
  }
}
