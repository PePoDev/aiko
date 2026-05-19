import 'source_freshness.dart';

class PredictionResult {
  const PredictionResult({
    required this.expectedValue,
    required this.lowValue,
    required this.highValue,
    required this.freshness,
  });

  final double expectedValue;
  final double lowValue;
  final double highValue;
  final SourceFreshness freshness;

  bool isUsable(DateTime now) => freshness.isFresh(now);
}
