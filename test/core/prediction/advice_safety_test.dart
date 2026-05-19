import 'package:aiko/core/prediction/advice_safety.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('marks tax, legal, and investment advice as sensitive', () {
    const safety = AdviceSafety(
      confidenceScore: 0.72,
      disclaimers: [AdviceDisclaimerType.tax],
    );

    expect(safety.needsSensitiveDisclaimer, isTrue);
  });

  test('requires source summaries for explainable advice', () {
    const safety = AdviceSafety(
      confidenceScore: 0.8,
      sources: [
        SourceSummary(
          label: 'Transactions',
          description: 'Last 30 days of categorized spending.',
        ),
      ],
    );

    expect(safety.isExplainable, isTrue);
  });
}
