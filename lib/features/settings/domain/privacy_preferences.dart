class PrivacyPreferences {
  const PrivacyPreferences({
    required this.aiAnalysisEnabled,
    required this.cloudSyncEnabled,
    required this.localOnlyMode,
  });

  final bool aiAnalysisEnabled;
  final bool cloudSyncEnabled;
  final bool localOnlyMode;

  bool get canAnalyzeFinancialData => aiAnalysisEnabled && !localOnlyMode;
  bool get canSyncToCloud => cloudSyncEnabled && !localOnlyMode;

  PrivacyPreferences copyWith({
    bool? aiAnalysisEnabled,
    bool? cloudSyncEnabled,
    bool? localOnlyMode,
  }) {
    final nextLocalOnly = localOnlyMode ?? this.localOnlyMode;
    return PrivacyPreferences(
      aiAnalysisEnabled: nextLocalOnly
          ? false
          : aiAnalysisEnabled ?? this.aiAnalysisEnabled,
      cloudSyncEnabled: nextLocalOnly
          ? false
          : cloudSyncEnabled ?? this.cloudSyncEnabled,
      localOnlyMode: nextLocalOnly,
    );
  }
}
