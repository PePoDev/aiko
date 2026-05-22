import 'package:aiko/core/monetization/feature_entitlement.dart';
import 'package:aiko/features/monetization/application/in_app_billing_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lists upgrades above current tier', () {
    final upgrades = const InAppBillingService().availableUpgrades(
      PlanTier.free,
    );

    expect(upgrades.map((quote) => quote.plan), [
      PlanTier.premium,
      PlanTier.pro,
    ]);
  });
}
