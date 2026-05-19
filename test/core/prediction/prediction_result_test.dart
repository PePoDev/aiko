import 'package:aiko/core/prediction/prediction_service.dart';
import 'package:aiko/core/prediction/source_freshness.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds prediction range and rejects stale data', () {
    final result = const PredictionService().scenario(
      baseline: 100,
      uncertaintyPercent: 10,
      freshness: SourceFreshness(
        sourceKey: 'transactions',
        status: SourceFreshnessStatus.stale,
      ),
    );

    expect(result.lowValue, 90);
    expect(result.highValue, 110);
    expect(result.isUsable(DateTime.utc(2026, 5, 19)), isFalse);
  });
}
