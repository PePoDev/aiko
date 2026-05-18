import '../domain/aiko_insight.dart';

class AikoInsightRepository {
  AikoInsightRepository({List<AikoInsight>? insights})
    : _insights =
          insights ??
          const [
            AikoInsight(
              id: 'food-up',
              userId: 'demo-user',
              type: AikoInsightType.diagnostic,
              title: 'Food spending increased',
              description: 'Food spending is up compared with last month.',
              recommendation: 'Keep weekend dining below 35 USD.',
              confidenceScore: 0.82,
              sourceDataSummary: ['transactions', 'category_totals'],
            ),
          ];

  final List<AikoInsight> _insights;

  Future<List<AikoInsight>> list({required bool aiConsentEnabled}) async {
    if (!aiConsentEnabled) {
      return const [];
    }
    return List.unmodifiable(_insights);
  }

  Future<void> dismiss(String id) async {
    final index = _insights.indexWhere((item) => item.id == id);
    if (index != -1) {
      _insights[index] = _insights[index].copyWith(
        status: AikoInsightStatus.dismissed,
      );
    }
  }
}
