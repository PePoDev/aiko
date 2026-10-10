import '../../../l10n/app_localizations.dart';

class LessonQuizQuestion {
  const LessonQuizQuestion({
    required this.prompt,
    required this.options,
    required this.correctOptionIndex,
  });

  final String prompt;
  final List<String> options;
  final int correctOptionIndex;

  bool isCorrect(int optionIndex) => optionIndex == correctOptionIndex;
}

class Lesson {
  const Lesson({
    required this.key,
    required this.title,
    required this.category,
    required this.summary,
    required this.estimatedMinutes,
    required this.quizQuestions,
  });

  /// Stable id, used to store the user's progress.
  final String key;
  final String title;
  final String category;
  final String summary;
  final int estimatedMinutes;
  final List<LessonQuizQuestion> quizQuestions;
}

/// How far the user got with a lesson: opened it ([read]) or answered its
/// whole quiz correctly ([completed]).
enum LessonProgress {
  notStarted,
  read,
  completed;

  /// How full the lesson's progress ring is.
  double get ringValue => switch (this) {
    LessonProgress.notStarted => 0,
    LessonProgress.read => 0.5,
    LessonProgress.completed => 1,
  };

  /// The further along of this and [other] (progress never goes back).
  LessonProgress atLeast(LessonProgress other) =>
      other.index > index ? other : this;
}

/// Whether [answers] (question index → chosen option) answer every question
/// in [questions] correctly.
bool quizPassed(List<LessonQuizQuestion> questions, Map<int, int> answers) {
  for (var i = 0; i < questions.length; i++) {
    final answer = answers[i];
    if (answer == null || !questions[i].isCorrect(answer)) return false;
  }
  return true;
}

/// Lessons in the current language. Glossary terms in their text are
/// highlighted inline (see [learningGlossary]).
List<Lesson> lessonsFor(AppLocalizations l10n) => [
  Lesson(
    key: 'budget-basics',
    title: l10n.lessonBudgetTitle,
    category: l10n.lessonBudgetCategory,
    summary: l10n.lessonBudgetSummary,
    estimatedMinutes: 6,
    quizQuestions: [
      LessonQuizQuestion(
        prompt: l10n.lessonBudgetQuestion,
        options: [l10n.lessonBudgetOptionCorrect, l10n.lessonBudgetOptionWrong],
        correctOptionIndex: 0,
      ),
    ],
  ),
  Lesson(
    key: 'emergency-fund',
    title: l10n.lessonEmergencyTitle,
    category: l10n.lessonEmergencyCategory,
    summary: l10n.lessonEmergencySummary,
    estimatedMinutes: 5,
    quizQuestions: [
      LessonQuizQuestion(
        prompt: l10n.lessonEmergencyQuestion,
        options: [
          l10n.lessonEmergencyOptionCorrect,
          l10n.lessonEmergencyOptionWrong,
        ],
        correctOptionIndex: 0,
      ),
    ],
  ),
  Lesson(
    key: 'credit-utilization',
    title: l10n.lessonCreditTitle,
    category: l10n.lessonCreditCategory,
    summary: l10n.lessonCreditSummary,
    estimatedMinutes: 7,
    quizQuestions: [
      LessonQuizQuestion(
        prompt: l10n.lessonCreditQuestion,
        options: [l10n.lessonCreditOptionWrong, l10n.lessonCreditOptionCorrect],
        correctOptionIndex: 1,
      ),
    ],
  ),
  Lesson(
    key: 'portfolio-rebalancing',
    title: l10n.lessonRebalanceTitle,
    category: l10n.lessonRebalanceCategory,
    summary: l10n.lessonRebalanceSummary,
    estimatedMinutes: 6,
    quizQuestions: [
      LessonQuizQuestion(
        prompt: l10n.lessonRebalanceQuestion,
        options: [
          l10n.lessonRebalanceOptionCorrect,
          l10n.lessonRebalanceOptionWrong,
        ],
        correctOptionIndex: 0,
      ),
    ],
  ),
];

Map<String, String> learningGlossary(AppLocalizations l10n) => {
  l10n.glossaryAprTerm: l10n.glossaryAprDefinition,
  l10n.glossarySafeToSpendTerm: l10n.glossarySafeToSpendDefinition,
  l10n.glossaryRebalancingTerm: l10n.glossaryRebalancingDefinition,
};
