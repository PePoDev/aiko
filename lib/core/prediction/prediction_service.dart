import 'prediction_result.dart';
import 'source_freshness.dart';

class PredictionService {
  const PredictionService();

  PredictionResult scenario({
    required double baseline,
    required double uncertaintyPercent,
    required SourceFreshness freshness,
  }) {
    final uncertainty = baseline * uncertaintyPercent / 100;
    return PredictionResult(
      expectedValue: baseline,
      lowValue: baseline - uncertainty,
      highValue: baseline + uncertainty,
      freshness: freshness,
    );
  }
}
