import 'prediction_result.dart';
import 'source_freshness.dart';

/// Light-weight scenario projection. The engine deliberately operates
/// in `double` because:
///
/// 1. Monte Carlo (sibling [MonteCarloEngine]) and forecasting in general use
///    statistical operations (sqrt, log, Box-Muller transforms, percentile
///    ranks) that are inherently floating-point and have no clean `Decimal`
///    analogue.
/// 2. The output is rounded at the formatter boundary (`formatCurrency`) so
///    the tiny rounding error from `double` arithmetic never reaches the
///    user-facing UI.
/// 3. Money is kept in `Money` / `Decimal` everywhere except the prediction
///    core; callers convert at the boundary (e.g.
///    `home_dashboard_screen.dart` line 1359-1361).
///
/// If precision ever matters at the prediction boundary, the upgrade path is
/// to wrap [Money] and accept a `Decimal` return; today the trade-off is
/// intentionally in favour of clarity (the alternative was a Decimal/Double
/// round-trip inside every [MonteCarloEngine.run] call).
class PredictionService {
  const PredictionService();

  /// Projects a baseline value into a low / expected / high band based on a
  /// symmetric [uncertaintyPercent] (e.g. 10.0 means ±10%).
  PredictionResult scenario({
    required double baselineAmount,
    required double uncertaintyPercent,
    required SourceFreshness freshness,
  }) {
    final uncertainty = baselineAmount * uncertaintyPercent / 100;
    return PredictionResult(
      expectedAmount: baselineAmount,
      lowAmount: baselineAmount - uncertainty,
      highAmount: baselineAmount + uncertainty,
      freshness: freshness,
    );
  }
}
