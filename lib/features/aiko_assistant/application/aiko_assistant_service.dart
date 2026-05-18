import '../../../core/money/money.dart';
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
}
