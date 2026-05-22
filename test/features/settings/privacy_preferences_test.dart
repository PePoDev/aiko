import 'package:aiko/features/settings/domain/privacy_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local-only mode disables AI analysis and cloud sync', () {
    final preferences = const PrivacyPreferences(
      aiAnalysisEnabled: true,
      cloudSyncEnabled: true,
      localOnlyMode: false,
    ).copyWith(localOnlyMode: true);

    expect(preferences.canAnalyzeFinancialData, isFalse);
    expect(preferences.canSyncToCloud, isFalse);
  });
}
