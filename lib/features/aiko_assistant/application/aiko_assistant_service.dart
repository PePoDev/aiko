import '../../../core/money/money.dart';
import '../../insights/domain/aiko_insight.dart';
import '../domain/aiko_response.dart';

class AikoAssistantService {
  const AikoAssistantService();

  AikoResponse safeToSpend({
    required bool aiConsentEnabled,
    required Money? safeToSpendAmount,
  }) {
    if (!aiConsentEnabled) {
      return const AikoResponse(
        type: AikoResponseType.missingData,
        answer: 'I need AI consent before I can analyze your financial data.',
        missingData: ['ai_consent'],
      );
    }
    if (safeToSpendAmount == null) {
      return const AikoResponse(
        type: AikoResponseType.missingData,
        answer:
            'I need income, bills, goals, and spending before I can estimate safe-to-spend.',
        missingData: ['income', 'bills', 'goals', 'transactions'],
      );
    }
    return AikoResponse(
      type: AikoResponseType.answer,
      answer: 'You have ${safeToSpendAmount.format()} safe to spend this week.',
      explanation:
          'This reserves bills, planned savings, goal contributions, and current spending.',
      sourceSummary: const [
        'monthly_income',
        'fixed_bills',
        'goal_contributions',
        'posted_transactions',
      ],
      recommendation: 'Keep flexible spending steady to stay on track.',
      disclaimer: 'This is an estimate based on the data in Aiko.',
    );
  }

  AikoResponse answerQuestion({
    required String question,
    required bool aiConsentEnabled,
    Money? safeToSpendAmount,
    List<AikoInsight> insights = const [],
  }) {
    final normalized = question.toLowerCase();
    if (normalized.contains('safe') || normalized.contains('spend')) {
      return safeToSpend(
        aiConsentEnabled: aiConsentEnabled,
        safeToSpendAmount: safeToSpendAmount,
      );
    }
    if (!aiConsentEnabled) {
      return const AikoResponse(
        type: AikoResponseType.missingData,
        answer: 'Turn on AI consent before I analyze personal finance data.',
        missingData: ['ai_consent'],
      );
    }
    if (normalized.contains('optimize') ||
        normalized.contains('improve') ||
        normalized.contains('recommend')) {
      final topInsight = insights.isEmpty ? null : insights.first;
      return AikoResponse(
        type: AikoResponseType.answer,
        answer:
            topInsight?.recommendation ??
            'Start with the largest recurring bill, then review budget categories that are above pace.',
        explanation:
            'Aiko prioritizes actions that are recurring, high-confidence, and easy to verify.',
        sourceSummary: const ['aiko_insights', 'budgets', 'subscriptions'],
        recommendation:
            topInsight?.title ?? 'Open Aiko Optimize for ranked next steps.',
        disclaimer: 'Aiko provides estimates, not certified financial advice.',
      );
    }
    return const AikoResponse(
      type: AikoResponseType.disclaimer,
      answer:
          'I can help with safe-to-spend, budgets, subscriptions, goals, calculators, and optimization questions.',
      disclaimer: 'Aiko provides estimates, not certified financial advice.',
    );
  }
}
