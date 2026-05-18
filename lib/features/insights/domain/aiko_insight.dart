enum AikoInsightType { descriptive, diagnostic, predictive, prescriptive }

enum AikoInsightStatus { newInsight, viewed, applied, dismissed, muted }

class AikoInsight {
  const AikoInsight({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.description,
    required this.recommendation,
    required this.confidenceScore,
    required this.sourceDataSummary,
    this.status = AikoInsightStatus.newInsight,
  });

  final String id;
  final String userId;
  final AikoInsightType type;
  final String title;
  final String description;
  final String recommendation;
  final double confidenceScore;
  final List<String> sourceDataSummary;
  final AikoInsightStatus status;

  AikoInsight copyWith({AikoInsightStatus? status}) {
    return AikoInsight(
      id: id,
      userId: userId,
      type: type,
      title: title,
      description: description,
      recommendation: recommendation,
      confidenceScore: confidenceScore,
      sourceDataSummary: sourceDataSummary,
      status: status ?? this.status,
    );
  }
}
