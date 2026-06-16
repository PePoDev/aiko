import 'package:aiko/features/dashboard/domain/dashboard_widget_preference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard preferences serialize for persistence', () {
    const preference = DashboardWidgetPreference(
      type: DashboardWidgetType.dueItems,
      isVisible: false,
      position: 3,
    );

    final restored = DashboardWidgetPreference.fromJson(preference.toJson());

    expect(restored.type, DashboardWidgetType.dueItems);
    expect(restored.isVisible, isFalse);
    expect(restored.position, 3);
    expect(restored.size, DashboardWidgetSize.full);
  });

  test('half-size default for daily spending and safe this week', () {
    final layout = DashboardWidgetPreference.defaultLayout;
    final daily = layout.firstWhere(
      (item) => item.type == DashboardWidgetType.dailySpending,
    );
    final safe = layout.firstWhere(
      (item) => item.type == DashboardWidgetType.safeThisWeek,
    );
    expect(daily.size, DashboardWidgetSize.half);
    expect(safe.size, DashboardWidgetSize.half);
  });

  test('size is intrinsic to the widget type', () {
    expect(
      DashboardWidgetType.dailySpending.defaultSize,
      DashboardWidgetSize.half,
    );
    expect(
      DashboardWidgetType.dailySummary.defaultSize,
      DashboardWidgetSize.full,
    );
  });

  test('default layout exposes overview panels as separate widgets', () {
    expect(
      DashboardWidgetPreference.defaultLayout.map((item) => item.type),
      containsAllInOrder(const [
        DashboardWidgetType.aikoWelcome,
        DashboardWidgetType.dailySpending,
        DashboardWidgetType.safeThisWeek,
        DashboardWidgetType.dailySummary,
        DashboardWidgetType.netEarnings,
        DashboardWidgetType.categoryBudgets,
        DashboardWidgetType.spendingCalendar,
        DashboardWidgetType.dueItems,
        DashboardWidgetType.thisMonthOverview,
        DashboardWidgetType.cashFlowMapping,
        DashboardWidgetType.aikoGoalSimulator,
      ]),
    );
    expect(DashboardWidgetType.dailySpending.label, 'Daily spending');
    expect(DashboardWidgetType.safeThisWeek.label, 'Safe this week');
    expect(DashboardWidgetType.dailySummary.label, 'Daily summary');
    expect(DashboardWidgetType.netEarnings.label, 'Net earnings');
    expect(DashboardWidgetType.categoryBudgets.label, 'Category budgets');
    expect(DashboardWidgetType.spendingCalendar.label, 'Spending calendar');
    expect(DashboardWidgetType.thisMonthOverview.label, 'This Month Overview');
    expect(DashboardWidgetType.cashFlowMapping.label, 'Cash flow mapping');
    expect(DashboardWidgetType.aikoGoalSimulator.label, 'Aiko Goal Simulator');
    expect(DashboardWidgetType.totalDebt.label, 'Total debt');
    expect(DashboardWidgetType.debtBreakdown.label, 'Debt breakdown');
  });
}
