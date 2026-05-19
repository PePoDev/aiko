enum OptimizationStatus { newSuggestion, tuned, dismissed, applied }

class OptimizationSuggestion {
  const OptimizationSuggestion({
    required this.title,
    required this.score,
    this.status = OptimizationStatus.newSuggestion,
  });

  final String title;
  final double score;
  final OptimizationStatus status;

  OptimizationSuggestion dismiss() => OptimizationSuggestion(
    title: title,
    score: score,
    status: OptimizationStatus.dismissed,
  );
}
