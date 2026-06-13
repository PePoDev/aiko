enum DashboardWidgetType {
  aikoWelcome,
  dailySpending,
  safeThisWeek,
  dailySummary,
  netEarnings,
  categoryBudgets,
  spendingCalendar,
  insights,
  dueItems,
  thisMonthOverview,
  cashFlowMapping,
  aikoGoalSimulator,
  totalBalance,
  leftToSave,
  cashFlow,
  netWorth,
  netWorthTrend,
  assetsLiabilities,
  topAssets;

  String get storageKey => name;

  String get label {
    return switch (this) {
      DashboardWidgetType.aikoWelcome => 'Aiko welcome',
      DashboardWidgetType.dailySpending => 'Daily spending',
      DashboardWidgetType.safeThisWeek => 'Safe this week',
      DashboardWidgetType.dailySummary => 'Daily summary',
      DashboardWidgetType.netEarnings => 'Net earnings',
      DashboardWidgetType.categoryBudgets => 'Category budgets',
      DashboardWidgetType.spendingCalendar => 'Spending calendar',
      DashboardWidgetType.insights => 'Insights',
      DashboardWidgetType.dueItems => 'Upcoming due dates',
      DashboardWidgetType.thisMonthOverview => 'This Month Overview',
      DashboardWidgetType.cashFlowMapping => 'Cash flow mapping',
      DashboardWidgetType.aikoGoalSimulator => 'Aiko Goal Simulator',
      DashboardWidgetType.totalBalance => 'Total balance',
      DashboardWidgetType.leftToSave => 'Left to save',
      DashboardWidgetType.cashFlow => 'Cash flow',
      DashboardWidgetType.netWorth => 'Net worth',
      DashboardWidgetType.netWorthTrend => 'Net worth trend',
      DashboardWidgetType.assetsLiabilities => 'Assets & liabilities',
      DashboardWidgetType.topAssets => 'Top assets',
    };
  }

  static DashboardWidgetType? fromStorageKey(String value) {
    final legacyType = switch (value) {
      'quickStats' => DashboardWidgetType.dailySpending,
      'analytics' => DashboardWidgetType.dailySummary,
      _ => null,
    };
    if (legacyType != null) {
      return legacyType;
    }

    for (final type in values) {
      if (type.storageKey == value) {
        return type;
      }
    }
    return null;
  }
}

class DashboardWidgetPreference {
  const DashboardWidgetPreference({
    required this.type,
    required this.isVisible,
    required this.position,
  });

  final DashboardWidgetType type;
  final bool isVisible;
  final int position;

  static const defaultLayout = [
    DashboardWidgetPreference(
      type: DashboardWidgetType.aikoWelcome,
      isVisible: true,
      position: 0,
    ),
    DashboardWidgetPreference(
      type: DashboardWidgetType.dailySpending,
      isVisible: true,
      position: 1,
    ),
    DashboardWidgetPreference(
      type: DashboardWidgetType.safeThisWeek,
      isVisible: true,
      position: 2,
    ),
    DashboardWidgetPreference(
      type: DashboardWidgetType.dailySummary,
      isVisible: true,
      position: 3,
    ),
    DashboardWidgetPreference(
      type: DashboardWidgetType.netEarnings,
      isVisible: true,
      position: 4,
    ),
    DashboardWidgetPreference(
      type: DashboardWidgetType.categoryBudgets,
      isVisible: true,
      position: 5,
    ),
    DashboardWidgetPreference(
      type: DashboardWidgetType.spendingCalendar,
      isVisible: true,
      position: 6,
    ),
    DashboardWidgetPreference(
      type: DashboardWidgetType.insights,
      isVisible: true,
      position: 7,
    ),
    DashboardWidgetPreference(
      type: DashboardWidgetType.dueItems,
      isVisible: true,
      position: 8,
    ),
    DashboardWidgetPreference(
      type: DashboardWidgetType.totalBalance,
      isVisible: true,
      position: 9,
    ),
    DashboardWidgetPreference(
      type: DashboardWidgetType.thisMonthOverview,
      isVisible: true,
      position: 10,
    ),
    DashboardWidgetPreference(
      type: DashboardWidgetType.leftToSave,
      isVisible: true,
      position: 11,
    ),
    DashboardWidgetPreference(
      type: DashboardWidgetType.cashFlow,
      isVisible: true,
      position: 12,
    ),
    DashboardWidgetPreference(
      type: DashboardWidgetType.cashFlowMapping,
      isVisible: true,
      position: 13,
    ),
    DashboardWidgetPreference(
      type: DashboardWidgetType.aikoGoalSimulator,
      isVisible: true,
      position: 14,
    ),
    DashboardWidgetPreference(
      type: DashboardWidgetType.netWorth,
      isVisible: true,
      position: 15,
    ),
    DashboardWidgetPreference(
      type: DashboardWidgetType.netWorthTrend,
      isVisible: true,
      position: 16,
    ),
    DashboardWidgetPreference(
      type: DashboardWidgetType.assetsLiabilities,
      isVisible: true,
      position: 17,
    ),
    DashboardWidgetPreference(
      type: DashboardWidgetType.topAssets,
      isVisible: true,
      position: 18,
    ),
  ];

  factory DashboardWidgetPreference.fromJson(Map<String, Object?> json) {
    final type = DashboardWidgetType.fromStorageKey(
      json['type'] as String? ?? '',
    );
    if (type == null) {
      throw const FormatException('Unknown dashboard widget type.');
    }
    return DashboardWidgetPreference(
      type: type,
      isVisible: json['isVisible'] as bool? ?? true,
      position: json['position'] as int? ?? type.index,
    );
  }

  DashboardWidgetPreference copyWith({bool? isVisible, int? position}) {
    return DashboardWidgetPreference(
      type: type,
      isVisible: isVisible ?? this.isVisible,
      position: position ?? this.position,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'type': type.storageKey,
      'isVisible': isVisible,
      'position': position,
    };
  }
}
