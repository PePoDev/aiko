import 'source_freshness.dart';

/// Output of [PredictionService.scenario]. Amounts are in the user's
/// `profile.baseCurrency` and are still in `double` — for the
/// design rationale (Monte Carlo needs floating-point, values are rounded at
/// the formatter boundary, callers convert at the boundary).
class PredictionResult {
  const PredictionResult({
    required this.expectedAmount,
    required this.lowAmount,
    required this.highAmount,
    required this.freshness,
  });

  final double expectedAmount;
  final double lowAmount;
  final double highAmount;
  final SourceFreshness freshness;

  bool isUsable(DateTime now) => freshness.isFresh(now);
}
