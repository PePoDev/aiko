import 'dart:math';

import '../../../l10n/app_localizations.dart';

/// Pool of pre-defined prompts surfaced as tappable suggestions on the Aiko
/// chat screen. A random subset is shown on the empty state and again as
/// "next" recommendations after each Aiko response.
abstract final class AikoPromptSuggestions {
  const AikoPromptSuggestions._();

  /// How many suggestions to display at once.
  static const count = 4;

  /// Every prompt, in the current language.
  static List<String> all(AppLocalizations l10n) => [
    // Safe-to-spend & budgeting
    l10n.aikoPrompt01,
    l10n.aikoPrompt02,
    l10n.aikoPrompt03,
    l10n.aikoPrompt04,
    l10n.aikoPrompt05,
    l10n.aikoPrompt06,
    // Goals & saving
    l10n.aikoPrompt07,
    l10n.aikoPrompt08,
    l10n.aikoPrompt09,
    l10n.aikoPrompt10,
    // Cash flow & income
    l10n.aikoPrompt11,
    l10n.aikoPrompt12,
    l10n.aikoPrompt13,
    l10n.aikoPrompt14,
    // Bills & subscriptions
    l10n.aikoPrompt15,
    l10n.aikoPrompt16,
    l10n.aikoPrompt17,
    // Debt & credit
    l10n.aikoPrompt18,
    l10n.aikoPrompt19,
    l10n.aikoPrompt20,
    // Net worth & investing
    l10n.aikoPrompt21,
    l10n.aikoPrompt22,
    l10n.aikoPrompt23,
    // Insights & check-ups
    l10n.aikoPrompt24,
    l10n.aikoPrompt25,
    l10n.aikoPrompt26,
    l10n.aikoPrompt27,
    l10n.aikoPrompt28,
  ];

  /// Returns [count] distinct prompts chosen at random.
  ///
  /// Pass a [seed] to get a stable selection across rebuilds (e.g. seed on the
  /// message count so the same turn keeps the same recommendations). Optionally
  /// [exclude] prompts already shown so recommendations don't repeat the user's
  /// last question.
  static List<String> sample(
    AppLocalizations l10n, {
    int? seed,
    Iterable<String> exclude = const [],
  }) {
    final pool = all(l10n).where((p) => !exclude.contains(p)).toList();
    pool.shuffle(Random(seed));
    return pool.take(count).toList(growable: false);
  }
}
