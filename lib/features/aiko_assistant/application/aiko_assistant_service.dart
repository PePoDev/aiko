import '../../../core/money/money.dart';
import '../../insights/domain/aiko_insight.dart';
import '../domain/aiko_response.dart';
import '../../accounts/domain/account.dart';
import '../../budgets/domain/budget.dart';
import '../../goals/domain/goal.dart';
import '../../transactions/domain/transaction.dart';

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
    List<Account> accounts = const [],
    List<Budget> budgets = const [],
    List<Goal> goals = const [],
    List<FinanceTransaction> transactions = const [],
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

    // Goals query
    if (normalized.contains('goal') || normalized.contains('saving')) {
      if (goals.isEmpty) {
        return const AikoResponse(
          type: AikoResponseType.answer,
          answer: "You don't have any active savings goals yet. You can tap the Budgets & Goals tab to create a new SMART saving goal!",
          explanation: "Setting goals is the first step to financial security.",
          disclaimer: "Estimated timeline and milestones are based on current contributions.",
        );
      }
      final buffer = StringBuffer();
      buffer.writeln("You have ${goals.length} active savings goal(s):");
      for (final goal in goals) {
        final progressPct = (goal.progress * 100).toStringAsFixed(0);
        buffer.writeln("• **${goal.name}**: ${goal.currentAmount.format()} of ${goal.targetAmount.format()} ($progressPct% complete, remaining ${goal.remaining.format()})");
      }
      return AikoResponse(
        type: AikoResponseType.answer,
        answer: buffer.toString().trim(),
        explanation: "Track your targets closely to optimize interest and automatic allocations.",
        sourceSummary: const ['goals'],
        recommendation: "Automate your savings contributions weekly to reach your goals faster.",
        disclaimer: "Aiko estimates timeline probability based on normal conditions.",
      );
    }

    // Net Worth / Balances query
    if (normalized.contains('net worth') ||
        normalized.contains('balance') ||
        normalized.contains('account') ||
        normalized.contains('wealth') ||
        normalized.contains('portfolio')) {
      if (accounts.isEmpty) {
        return const AikoResponse(
          type: AikoResponseType.answer,
          answer: "You haven't set up any financial accounts yet. Link cash, bank accounts, or investments in your Accounts workspace to see your net worth!",
          explanation: "Net worth is your total assets minus liabilities.",
        );
      }
      final double totalValue = accounts.fold<double>(0, (sum, acc) {
        final double factor = acc.type == AccountType.loan || acc.type == AccountType.liability || acc.type == AccountType.creditCard ? -1.0 : 1.0;
        return sum + (acc.currentBalance.amount.toDouble() * factor);
      });
      final currency = accounts.isNotEmpty ? accounts.first.currentBalance.currency : 'USD';
      final netWorthMoney = Money.parse(totalValue.toString(), currency);

      final buffer = StringBuffer();
      buffer.writeln("Your estimated net worth is **${netWorthMoney.format()}** across ${accounts.length} active account(s):");
      for (final acc in accounts) {
        buffer.writeln("• **${acc.name}** (${acc.type.name}): ${acc.currentBalance.format()}");
      }
      return AikoResponse(
        type: AikoResponseType.answer,
        answer: buffer.toString().trim(),
        explanation: "Keep track of credit card balances and loan payments to grow your overall net worth.",
        sourceSummary: const ['accounts'],
        recommendation: "Review your portfolio weekly to detect asset allocation drift.",
        disclaimer: "This includes cash, bank accounts, loans, and other assets recorded manually or linked.",
      );
    }

    // Budgets query
    if (normalized.contains('budget') || normalized.contains('limit') || normalized.contains('envelope')) {
      if (budgets.isEmpty) {
        return const AikoResponse(
          type: AikoResponseType.answer,
          answer: "You don't have any active budgets set up yet. Tap the Budgets & Goals tab to create category limits, or select a pre-made 50/30/20 template!",
          explanation: "Setting category budgets prevents overspending and reserves cash for your savings goals.",
        );
      }
      final buffer = StringBuffer();
      buffer.writeln("You have ${budgets.length} active category budget(s):");
      for (final budget in budgets) {
        buffer.writeln("• **${budget.name}**: ${budget.amount.format()} per month");
      }
      return AikoResponse(
        type: AikoResponseType.answer,
        answer: buffer.toString().trim(),
        explanation: "Aiko tracks real-time spending pace against these category limits.",
        sourceSummary: const ['budgets'],
        recommendation: "Consider moving category envelopes around if you overrun a category budget.",
        disclaimer: "Budgets are recalculated monthly based on your selected starting date.",
      );
    }

    // Transactions query / Merchant query
    final merchantMatch = transactions.where((tx) {
      final merchant = tx.merchant?.toLowerCase() ?? '';
      final note = tx.note?.toLowerCase() ?? '';
      return merchant.contains(normalized) || note.contains(normalized);
    }).toList();

    if (merchantMatch.isNotEmpty) {
      final buffer = StringBuffer();
      final double totalSpent = merchantMatch.fold(0.0, (sum, tx) => sum + tx.amount.amount.toDouble());
      final currency = merchantMatch.first.amount.currency;
      final totalMoney = Money.parse(totalSpent.toString(), currency);
      
      buffer.writeln("Found ${merchantMatch.length} transaction(s) matching your query, totaling **${totalMoney.format()}**:");
      // Show up to 5 matching
      final itemsToShow = merchantMatch.take(5).toList();
      for (final tx in itemsToShow) {
        final sign = tx.isExpense ? "-" : "+";
        buffer.writeln("• **${tx.merchant ?? 'Unknown Merchant'}**: $sign${tx.amount.format()} (${tx.date.toString().substring(0, 10)})");
      }
      if (merchantMatch.length > 5) {
        buffer.writeln("• *and ${merchantMatch.length - 5} more transactions...*");
      }
      return AikoResponse(
        type: AikoResponseType.answer,
        answer: buffer.toString().trim(),
        explanation: "Matches scanned from your posted and draft transaction history.",
        sourceSummary: const ['posted_transactions'],
        disclaimer: "Only showing matching transaction items recorded in Aiko.",
      );
    }

    if (normalized.contains('transaction') || normalized.contains('spend') || normalized.contains('history') || normalized.contains('record')) {
      if (transactions.isEmpty) {
        return const AikoResponse(
          type: AikoResponseType.answer,
          answer: "No transactions have been recorded yet. You can tap '+' on the Home tab to log your income or expenses!",
          explanation: "Transaction logs are used to compute your cash flow, budgets, and safe-to-spend cushion.",
        );
      }
      final buffer = StringBuffer();
      buffer.writeln("Here are your 5 most recent transactions:");
      final recent = transactions.take(5).toList();
      for (final tx in recent) {
        final sign = tx.isExpense ? "-" : "+";
        buffer.writeln("• **${tx.merchant ?? 'Unknown Merchant'}**: $sign${tx.amount.format()} (${tx.date.toString().substring(0, 10)}) - ${tx.type.name}");
      }
      return AikoResponse(
        type: AikoResponseType.answer,
        answer: buffer.toString().trim(),
        explanation: "Showing your latest posted transaction history.",
        sourceSummary: const ['posted_transactions'],
        disclaimer: "Recalculated instantly in real-time.",
      );
    }

    return const AikoResponse(
      type: AikoResponseType.disclaimer,
      answer:
          "I can help you analyze your **safe-to-spend**, **savings goals**, **net worth**, active **budgets**, **calculators**, and **transaction history**! Type something like 'what is my net worth?' or 'what are my goals?'",
      disclaimer: 'Aiko provides estimates, not certified financial advice.',
    );
  }
}
