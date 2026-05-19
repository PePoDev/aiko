import '../domain/optimization_suggestion.dart';

class AikoOptimizeService {
  const AikoOptimizeService();

  List<OptimizationSuggestion> rank(List<OptimizationSuggestion> suggestions) {
    final sorted = [...suggestions];
    sorted.sort((a, b) => b.score.compareTo(a.score));
    return sorted;
  }
}
