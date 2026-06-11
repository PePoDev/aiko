import 'package:aiko/features/dashboard/domain/dashboard_widget_preference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard preferences capture ordering and visibility', () {
    const preference = DashboardWidgetPreference(
      type: DashboardWidgetType.quickStats,
      isVisible: true,
      position: 0,
    );

    expect(preference.type, DashboardWidgetType.quickStats);
    expect(preference.isVisible, isTrue);
    expect(preference.position, 0);
  });

  test('dashboard preferences serialize for persistence', () {
    const preference = DashboardWidgetPreference(
      type: DashboardWidgetType.insights,
      isVisible: false,
      position: 3,
    );

    final restored = DashboardWidgetPreference.fromJson(preference.toJson());

    expect(restored.type, DashboardWidgetType.insights);
    expect(restored.isVisible, isFalse);
    expect(restored.position, 3);
  });
}
