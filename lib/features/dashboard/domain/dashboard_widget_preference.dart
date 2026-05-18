enum DashboardWidgetSize { compact, expanded }

class DashboardWidgetPreference {
  const DashboardWidgetPreference({
    required this.widgetKey,
    required this.isVisible,
    required this.position,
    required this.size,
  });

  final String widgetKey;
  final bool isVisible;
  final int position;
  final DashboardWidgetSize size;
}
