import 'package:aiko/features/aiko_optimize/application/aiko_optimize_service.dart';
import 'package:aiko/features/aiko_optimize/domain/optimization_suggestion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ranks and dismisses optimization suggestions', () {
    final ranked = const AikoOptimizeService().rank([
      const OptimizationSuggestion(title: 'Low', score: 0.2),
      const OptimizationSuggestion(title: 'High', score: 0.9),
    ]);

    expect(ranked.first.title, 'High');
    expect(ranked.first.dismiss().status, OptimizationStatus.dismissed);
  });
}
