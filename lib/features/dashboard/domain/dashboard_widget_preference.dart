/// Widgets shown on the home dashboard. The set and order are fixed in
/// `home_dashboard_screen.dart`; the dashboard is not user-customizable.
enum DashboardWidgetType {
  aikoWelcome,
  dailySpending,
  dailySummary,
  netEarnings,
  categoryBudgets,
  spendingCalendar,
  cashFlowMapping;

  /// Intrinsic width on the dashboard grid. Every widget is full-width today;
  /// the half option is kept for future compact summaries.
  DashboardWidgetSize get defaultSize => DashboardWidgetSize.full;
}

/// Width a widget occupies in the dashboard grid.
enum DashboardWidgetSize { full, half }
