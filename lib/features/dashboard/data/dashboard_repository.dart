import '../../../core/money/money.dart';
import '../domain/dashboard_summary.dart';
import '../domain/dashboard_widget_preference.dart';

class DashboardRepository {
  Future<DashboardSummary> loadSummary() async {
    return DashboardSummary(
      netWorth: Money.parse('12850', 'USD'),
      totalCash: Money.parse('3420', 'USD'),
      monthlyIncome: Money.parse('5200', 'USD'),
      monthlySpending: Money.parse('2180', 'USD'),
      safeToSpend: Money.parse('245', 'USD'),
      paceStatus: const PaceStatus(
        percentOfBudgetUsed: 62,
        daysElapsedRatio: 0.58,
      ),
    );
  }

  Future<List<DashboardWidgetPreference>> loadPreferences() async {
    return const [
      DashboardWidgetPreference(
        widgetKey: 'safe_to_spend',
        isVisible: true,
        position: 0,
        size: DashboardWidgetSize.expanded,
      ),
    ];
  }
}
