enum DashboardWidgetType {
  aikoWelcome,
  dailySpending,
  safeThisWeek,
  dailySummary,
  netEarnings,
  categoryBudgets,
  spendingCalendar,
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
  topAssets,
  totalDebt,
  debtBreakdown,
  taxLiability,
  taxBreakdown,
  topDeductions;

  String get storageKey => name;

  /// Placeholder types kept only so legacy stored layouts still deserialize.
  /// They render nothing, so they must not appear in the dashboard or the
  /// "Add widgets" picker.
  static const _deadTypes = {
    totalDebt,
    debtBreakdown,
    taxLiability,
    taxBreakdown,
    topDeductions,
  };

  bool get isRenderable => !_deadTypes.contains(this);

  /// Intrinsic width on the dashboard grid. A couple of compact summaries are
  /// half-width so two share a row; everything else is full. This is a property
  /// of the widget, not a user setting.
  DashboardWidgetSize get defaultSize => switch (this) {
    DashboardWidgetType.dailySpending ||
    DashboardWidgetType.safeThisWeek => DashboardWidgetSize.half,
    _ => DashboardWidgetSize.full,
  };

  String get label {
    return switch (this) {
      DashboardWidgetType.aikoWelcome => 'Aiko welcome',
      DashboardWidgetType.dailySpending => 'Daily spending',
      DashboardWidgetType.safeThisWeek => 'Safe this week',
      DashboardWidgetType.dailySummary => 'Daily summary',
      DashboardWidgetType.netEarnings => 'Net earnings',
      DashboardWidgetType.categoryBudgets => 'Category budgets',
      DashboardWidgetType.spendingCalendar => 'Spending calendar',
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
      DashboardWidgetType.totalDebt => 'Total debt',
      DashboardWidgetType.debtBreakdown => 'Debt breakdown',
      DashboardWidgetType.taxLiability => 'Tax liability',
      DashboardWidgetType.taxBreakdown => 'Tax breakdown',
      DashboardWidgetType.topDeductions => 'Top deductions',
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

/// Width a single widget occupies inside the dashboard grid.
///
/// - [full] spans the whole row (one column).
/// - [half] spans one of two columns; two consecutive half widgets share a
///   row. An unpaired trailing half widget sits on the left and leaves the
///   right cell empty.
enum DashboardWidgetSize { full, half }

class DashboardWidgetPreference {
  const DashboardWidgetPreference({
    required this.type,
    required this.isVisible,
    required this.position,
  });

  final DashboardWidgetType type;
  final bool isVisible;
  final int position;

  /// Intrinsic to the widget type, not a stored user setting.
  DashboardWidgetSize get size => type.defaultSize;

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
      type: DashboardWidgetType.dueItems,
      isVisible: true,
      position: 7,
    ),
    DashboardWidgetPreference(
      type: DashboardWidgetType.totalBalance,
      isVisible: true,
      position: 8,
    ),
    DashboardWidgetPreference(
      type: DashboardWidgetType.thisMonthOverview,
      isVisible: true,
      position: 9,
    ),
    DashboardWidgetPreference(
      type: DashboardWidgetType.leftToSave,
      isVisible: true,
      position: 10,
    ),
    DashboardWidgetPreference(
      type: DashboardWidgetType.cashFlow,
      isVisible: true,
      position: 11,
    ),
    DashboardWidgetPreference(
      type: DashboardWidgetType.cashFlowMapping,
      isVisible: true,
      position: 12,
    ),
    DashboardWidgetPreference(
      type: DashboardWidgetType.aikoGoalSimulator,
      isVisible: true,
      position: 13,
    ),
    DashboardWidgetPreference(
      type: DashboardWidgetType.netWorth,
      isVisible: true,
      position: 14,
    ),
    DashboardWidgetPreference(
      type: DashboardWidgetType.netWorthTrend,
      isVisible: true,
      position: 15,
    ),
    DashboardWidgetPreference(
      type: DashboardWidgetType.assetsLiabilities,
      isVisible: true,
      position: 16,
    ),
    DashboardWidgetPreference(
      type: DashboardWidgetType.topAssets,
      isVisible: true,
      position: 17,
    ),
    DashboardWidgetPreference(
      type: DashboardWidgetType.totalDebt,
      isVisible: true,
      position: 18,
    ),
    DashboardWidgetPreference(
      type: DashboardWidgetType.debtBreakdown,
      isVisible: true,
      position: 19,
    ),
    DashboardWidgetPreference(
      type: DashboardWidgetType.taxLiability,
      isVisible: true,
      position: 20,
    ),
    DashboardWidgetPreference(
      type: DashboardWidgetType.taxBreakdown,
      isVisible: true,
      position: 21,
    ),
    DashboardWidgetPreference(
      type: DashboardWidgetType.topDeductions,
      isVisible: true,
      position: 22,
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
