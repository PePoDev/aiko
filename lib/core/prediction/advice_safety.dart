enum AdviceDisclaimerType { financialEstimate, investment, tax, legal }

class SourceSummary {
  const SourceSummary({
    required this.label,
    required this.description,
    this.updatedAt,
  });

  final String label;
  final String description;
  final DateTime? updatedAt;
}

class AdviceSafety {
  const AdviceSafety({
    required this.confidenceScore,
    this.disclaimers = const <AdviceDisclaimerType>[],
    this.sources = const <SourceSummary>[],
  }) : assert(confidenceScore >= 0 && confidenceScore <= 1);

  final double confidenceScore;
  final List<AdviceDisclaimerType> disclaimers;
  final List<SourceSummary> sources;

  bool get needsSensitiveDisclaimer =>
      disclaimers.contains(AdviceDisclaimerType.investment) ||
      disclaimers.contains(AdviceDisclaimerType.tax) ||
      disclaimers.contains(AdviceDisclaimerType.legal);

  bool get isExplainable => sources.isNotEmpty;
}
