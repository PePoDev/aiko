enum DashboardWidgetType {
  aikoWelcome,
  quickStats,
  analytics,
  insights,
  dueItems;

  String get storageKey => name;

  String get label {
    return switch (this) {
      DashboardWidgetType.aikoWelcome => 'Aiko welcome',
      DashboardWidgetType.quickStats => 'Quick stats',
      DashboardWidgetType.analytics => 'Analytics',
      DashboardWidgetType.insights => 'Insights',
      DashboardWidgetType.dueItems => 'Due items',
    };
  }

  static DashboardWidgetType? fromStorageKey(String value) {
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
      type: DashboardWidgetType.quickStats,
      isVisible: true,
      position: 1,
    ),
    DashboardWidgetPreference(
      type: DashboardWidgetType.analytics,
      isVisible: true,
      position: 2,
    ),
    DashboardWidgetPreference(
      type: DashboardWidgetType.insights,
      isVisible: true,
      position: 3,
    ),
    DashboardWidgetPreference(
      type: DashboardWidgetType.dueItems,
      isVisible: true,
      position: 4,
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
