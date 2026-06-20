/// Widgets shown on the home dashboard. The set and order are fixed in
/// `home_dashboard_screen.dart`; the dashboard is not user-customizable.
enum DashboardWidgetType {
  aikoWelcome,
  dailySpending,
  safeThisWeek,
  dailySummary,
  netEarnings,
  categoryBudgets,
  spendingCalendar,
  cashFlowMapping,
  leftToSave,
  cashFlow,
  topAssets;

  /// Intrinsic width on the dashboard grid. A couple of compact summaries are
  /// half-width so two share a row; everything else is full.
  DashboardWidgetSize get defaultSize => switch (this) {
    DashboardWidgetType.dailySpending ||
    DashboardWidgetType.safeThisWeek => DashboardWidgetSize.half,
    _ => DashboardWidgetSize.full,
  };
}

/// Width a widget occupies in the dashboard grid.
enum DashboardWidgetSize { full, half }
