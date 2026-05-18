enum AikoResponseType { answer, missingData, disclaimer }

class AikoResponse {
  const AikoResponse({
    required this.type,
    required this.answer,
    this.explanation,
    this.sourceSummary = const [],
    this.recommendation,
    this.disclaimer,
    this.missingData = const [],
  });

  final AikoResponseType type;
  final String answer;
  final String? explanation;
  final List<String> sourceSummary;
  final String? recommendation;
  final String? disclaimer;
  final List<String> missingData;

  bool get hasDisclaimer => disclaimer != null && disclaimer!.isNotEmpty;
}
