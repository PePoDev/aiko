import 'package:aiko/features/dashboard/domain/dashboard_widget_preference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard preferences capture ordering and visibility', () {
    const preference = DashboardWidgetPreference(
      widgetKey: 'safe_to_spend',
      isVisible: true,
      position: 0,
      size: DashboardWidgetSize.expanded,
    );

    expect(preference.isVisible, isTrue);
    expect(preference.position, 0);
  });
}
