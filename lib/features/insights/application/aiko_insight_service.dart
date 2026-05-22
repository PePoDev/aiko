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

  AikoInsight monthlyReview({
    required String userId,
    required String monthLabel,
    required Money income,
    required Money expenses,
    required Money savings,
    required String topCategoryName,
  }) {
    final leftover = income - expenses - savings;
    return AikoInsight(
      id: 'review-$monthLabel',
      userId: userId,
      type: AikoInsightType.diagnostic,
      title: '$monthLabel money review',
      description:
          'Income was ${income.format()}, expenses were ${expenses.format()}, and planned savings were ${savings.format()}.',
      recommendation: leftover.isNegative
          ? 'Review $topCategoryName and fixed bills to bring cash flow positive.'
          : 'Keep the ${leftover.format()} cushion for next month or move part of it to a goal.',
      confidenceScore: 0.84,
      sourceDataSummary: const [
        'monthly_income',
        'transactions',
        'savings_goals',
        'categories',
      ],
    );
  }

  List<CashFlowNode> sankeyFlow({
    required Money income,
    required Money bills,
    required Money spending,
    required Money savings,
    required Money goals,
  }) {
    final leftover = income - bills - spending - savings - goals;
    return [
      CashFlowNode(label: 'Income', amount: bills, targetLabel: 'Bills'),
      CashFlowNode(label: 'Income', amount: spending, targetLabel: 'Spending'),
      CashFlowNode(label: 'Income', amount: savings, targetLabel: 'Savings'),
      CashFlowNode(label: 'Income', amount: goals, targetLabel: 'Goals'),
      CashFlowNode(label: 'Income', amount: leftover, targetLabel: 'Leftover'),
    ];
  }
}

class CashFlowNode {
  const CashFlowNode({
    required this.label,
    required this.amount,
    required this.targetLabel,
  });

  final String label;
  final Money amount;
  final String targetLabel;
}
