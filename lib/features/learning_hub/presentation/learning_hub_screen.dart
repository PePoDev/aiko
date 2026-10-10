import 'package:flutter/material.dart';

import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';
import '../../../l10n/l10n.dart';
import 'inline_glossary_text.dart';

class LearningHubScreen extends StatelessWidget {
  const LearningHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lessons = _lessons(l10n);
    final glossary = _glossary(l10n);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.toolLearningHub)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FinanceCard(
              title: l10n.learningRecommendedLessons,
              icon: Icons.school_outlined,
              accentColor: AikoColors.premiumPurple,
              prominent: true,
              child: Column(
                children: [
                  for (final lesson in lessons)
                    _LessonTile(lesson: lesson, glossary: glossary),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FinanceCard(
              title: l10n.learningQuizzes,
              icon: Icons.quiz_outlined,
              accentColor: AikoColors.deepBlue,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final lesson in lessons.where(
                    (lesson) => lesson.quizQuestions.isNotEmpty,
                  ))
                    InlineGlossaryText(
                      text: l10n.learningQuizSummary(
                        lesson.title,
                        lesson.quizQuestions.length,
                      ),
                      glossary: glossary,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({required this.lesson, required this.glossary});

  final _Lesson lesson;
  final Map<String, String> glossary;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircularProgressIndicator(
        value: _completionPercent(lesson.progress),
        strokeWidth: 4,
      ),
      title: InlineGlossaryText(text: lesson.title, glossary: glossary),
      subtitle: InlineGlossaryText(
        text:
            '${context.l10n.learningLessonMeta(lesson.category, lesson.estimatedMinutes)}'
            '\n${lesson.summary}',
        glossary: glossary,
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

typedef _Lesson = ({
  String key,
  String title,
  String category,
  String summary,
  int estimatedMinutes,
  _LessonProgress progress,
  List<_LessonQuizQuestion> quizQuestions,
});

typedef _LessonQuizQuestion = ({
  String prompt,
  List<String> options,
  int correctOptionIndex,
});

enum _LessonProgress { notStarted, inProgress, completed }

double _completionPercent(_LessonProgress progress) => switch (progress) {
  _LessonProgress.notStarted => 0,
  _LessonProgress.inProgress => 0.5,
  _LessonProgress.completed => 1,
};

/// Lessons in the current language. Glossary terms in their text are
/// highlighted inline (see [_glossary]).
List<_Lesson> _lessons(AppLocalizations l10n) => [
  (
    key: 'budget-basics',
    title: l10n.lessonBudgetTitle,
    category: l10n.lessonBudgetCategory,
    summary: l10n.lessonBudgetSummary,
    estimatedMinutes: 6,
    progress: _LessonProgress.inProgress,
    quizQuestions: [
      (
        prompt: l10n.lessonBudgetQuestion,
        options: [l10n.lessonBudgetOptionCorrect, l10n.lessonBudgetOptionWrong],
        correctOptionIndex: 0,
      ),
    ],
  ),
  (
    key: 'emergency-fund',
    title: l10n.lessonEmergencyTitle,
    category: l10n.lessonEmergencyCategory,
    summary: l10n.lessonEmergencySummary,
    estimatedMinutes: 5,
    progress: _LessonProgress.notStarted,
    quizQuestions: [
      (
        prompt: l10n.lessonEmergencyQuestion,
        options: [
          l10n.lessonEmergencyOptionCorrect,
          l10n.lessonEmergencyOptionWrong,
        ],
        correctOptionIndex: 0,
      ),
    ],
  ),
  (
    key: 'credit-utilization',
    title: l10n.lessonCreditTitle,
    category: l10n.lessonCreditCategory,
    summary: l10n.lessonCreditSummary,
    estimatedMinutes: 7,
    progress: _LessonProgress.completed,
    quizQuestions: [
      (
        prompt: l10n.lessonCreditQuestion,
        options: [l10n.lessonCreditOptionWrong, l10n.lessonCreditOptionCorrect],
        correctOptionIndex: 1,
      ),
    ],
  ),
  (
    key: 'portfolio-rebalancing',
    title: l10n.lessonRebalanceTitle,
    category: l10n.lessonRebalanceCategory,
    summary: l10n.lessonRebalanceSummary,
    estimatedMinutes: 6,
    progress: _LessonProgress.notStarted,
    quizQuestions: [
      (
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

Map<String, String> _glossary(AppLocalizations l10n) => {
  l10n.glossaryAprTerm: l10n.glossaryAprDefinition,
  l10n.glossarySafeToSpendTerm: l10n.glossarySafeToSpendDefinition,
  l10n.glossaryRebalancingTerm: l10n.glossaryRebalancingDefinition,
};
