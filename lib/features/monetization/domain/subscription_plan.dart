import '../../../core/monetization/feature_entitlement.dart';

class SubscriptionPlan {
  const SubscriptionPlan({
    required this.tier,
    required this.name,
    required this.features,
  });

  final PlanTier tier;
  final String name;
  final List<String> features;
}
