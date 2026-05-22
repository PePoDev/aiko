import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/aiko_insight.dart';

class AikoInsightRepository {
  const AikoInsightRepository();

  Future<List<AikoInsight>> list({required bool aiConsentEnabled}) async {
    if (!aiConsentEnabled) {
      return const [];
    }

    final session = AikoSupabase.requireSession();
    final response = await session.client
        .from('aiko_insights')
        .select()
        .eq('user_id', session.userId)
        .neq('status', 'dismissed')
        .order('created_at', ascending: false);

    return response
        .map((row) => _fromRow(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<void> dismiss(String id) async {
    final session = AikoSupabase.requireSession();
    await session.client
        .from('aiko_insights')
        .update({
          'status': 'dismissed',
          'dismissed_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .eq('user_id', session.userId);
  }

  static AikoInsight _fromRow(Map<String, dynamic> row) {
    final type = AikoInsightType.values.firstWhere(
      (item) => item.name == row['insight_type'],
      orElse: () => AikoInsightType.descriptive,
    );
    final status = switch (row['status'] as String? ?? 'new') {
      'new' => AikoInsightStatus.newInsight,
      final value => AikoInsightStatus.values.firstWhere(
        (item) => item.name == value,
        orElse: () => AikoInsightStatus.newInsight,
      ),
    };
    final sourceDataSummary =
        (row['source_data_summary'] as List?)
            ?.map((item) => item.toString())
            .toList() ??
        const <String>[];

    return AikoInsight(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      type: type,
      title: row['title'] as String,
      description: row['description'] as String,
      recommendation: row['recommendation'] as String,
      confidenceScore: (row['confidence_score'] as num?)?.toDouble() ?? 0.7,
      sourceDataSummary: sourceDataSummary,
      status: status,
    );
  }
}
