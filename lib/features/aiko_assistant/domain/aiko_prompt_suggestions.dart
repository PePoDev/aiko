import 'dart:math';

/// Pool of pre-defined prompts surfaced as tappable suggestions on the Aiko
/// chat screen. A random subset is shown on the empty state and again as
/// "next" recommendations after each Aiko response.
abstract final class AikoPromptSuggestions {
  const AikoPromptSuggestions._();

  /// How many suggestions to display at once.
  static const count = 4;

  static const all = <String>[
    // Safe-to-spend & budgeting
    'How much can I safely spend?',
    'How am I doing against my budget?',
    'Which budgets am I close to maxing out?',
    'Where can I cut back?',
    'What are my biggest spending categories?',
    'Did my spending go up this month?',
    // Goals & saving
    'Am I on track for my goals?',
    'How can I reach my goals faster?',
    'How much should I save each month?',
    'Suggest a realistic savings plan.',
    // Cash flow & income
    'How did I spend this month?',
    "What's my cash flow looking like?",
    'Will I have money left at month end?',
    'How do my income and expenses compare?',
    // Bills & subscriptions
    'What bills are due soon?',
    'Which subscriptions could I cancel?',
    'Am I paying for anything I forgot about?',
    // Debt & credit
    'How should I pay off my debt?',
    "What's my credit card utilization?",
    'Should I use snowball or avalanche?',
    // Net worth & investing
    "What's my net worth right now?",
    'How is my portfolio allocated?',
    'Is my emergency fund big enough?',
    // Insights & check-ups
    'Give me a quick money check-up.',
    'Any unusual spending this month?',
    'What should I focus on this week?',
    'Show me one way to improve my finances.',
    'Summarize my finances for me.',
  ];

  /// Returns [count] distinct prompts chosen at random.
  ///
  /// Pass a [seed] to get a stable selection across rebuilds (e.g. seed on the
  /// message count so the same turn keeps the same recommendations). Optionally
  /// [exclude] prompts already shown so recommendations don't repeat the user's
  /// last question.
  static List<String> sample({int? seed, Iterable<String> exclude = const []}) {
    final pool = all.where((p) => !exclude.contains(p)).toList();
    pool.shuffle(Random(seed));
    return pool.take(count).toList(growable: false);
  }
}
