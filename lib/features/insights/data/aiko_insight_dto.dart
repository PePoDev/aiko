import '../domain/aiko_insight.dart';

class AikoInsightDto {
  const AikoInsightDto(this.json);

  final Map<String, dynamic> json;

  AikoInsight toDomain() {
    return AikoInsight(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: AikoInsightType.values.byName(
        json['insight_type'] as String? ?? 'descriptive',
      ),
      title: json['title'] as String,
      description: json['description'] as String,
      recommendation: json['recommendation'] as String,
      confidenceScore: (json['confidence_score'] as num? ?? 0.7).toDouble(),
      sourceDataSummary: List<String>.from(
        json['source_data_summary'] as List? ?? [],
      ),
    );
  }
}
