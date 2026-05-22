enum OptimizationStatus { newSuggestion, tuned, dismissed, applied }

class OptimizationSuggestion {
  const OptimizationSuggestion({
    required this.title,
    required this.score,
    this.reason = '',
    this.actionLabel = 'Review',
    this.sourceData = const [],
    this.status = OptimizationStatus.newSuggestion,
  });

  final String title;
  final double score;
  final String reason;
  final String actionLabel;
  final List<String> sourceData;
  final OptimizationStatus status;

  OptimizationSuggestion dismiss() => OptimizationSuggestion(
    title: title,
    score: score,
    reason: reason,
    actionLabel: actionLabel,
    sourceData: sourceData,
    status: OptimizationStatus.dismissed,
  );
}
