import '../../../core/money/money.dart';
import '../domain/aiko_insight.dart';

class AikoInsightService {
  const AikoInsightService();

  AikoInsight budgetThreshold({
    required String userId,
    required String categoryName,
    required double percentUsed,
    required Money dailyLimit,
  }) {
    return AikoInsight(
      id: 'budget-$categoryName',
      userId: userId,
      type: AikoInsightType.prescriptive,
      title: '$categoryName budget is ${percentUsed.toStringAsFixed(0)}% used',
      description: 'You are a little above your target pace this month.',
      recommendation:
          'Keep $categoryName under ${dailyLimit.format()} per day to stay on track.',
      confidenceScore: 0.8,
      sourceDataSummary: const ['budget', 'transactions'],
    );
  }
}
