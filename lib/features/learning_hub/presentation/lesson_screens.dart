import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/layout/adaptive_presentation.dart';
import '../../../shared/widgets/aiko_data_widgets.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';
import '../application/lesson_progress.dart';
import '../domain/lesson.dart';
import 'inline_glossary_text.dart';

/// Accessible name of a lesson's progress ring.
String lessonProgressLabel(LessonProgress progress, AppLocalizations l10n) =>
    switch (progress) {
      LessonProgress.notStarted => l10n.learningProgressNotStarted,
      LessonProgress.read => l10n.learningProgressRead,
      LessonProgress.completed => l10n.learningProgressCompleted,
    };

Lesson? _lessonByKey(String key, AppLocalizations l10n) {
  for (final lesson in lessonsFor(l10n)) {
    if (lesson.key == key) return lesson;
  }
  return null;
}

/// One lesson: its summary with inline glossary terms, and a way into its
/// quiz. Opening it marks the lesson as read.
class LessonScreen extends ConsumerStatefulWidget {
  const LessonScreen({required this.lessonKey, super.key});

  final String lessonKey;

  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<LessonScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref
          .read(lessonProgressProvider.notifier)
          .record(widget.lessonKey, LessonProgress.read);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lesson = _lessonByKey(widget.lessonKey, l10n);
    final theme = Theme.of(context);
    final glossary = learningGlossary(l10n);
    final progress =
        ref.watch(lessonProgressProvider).value?[widget.lessonKey] ??
        LessonProgress.notStarted;

    return Scaffold(
      appBar: AppBar(title: Text(lesson?.category ?? l10n.toolLearningHub)),
      body: lesson == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                FinanceCard(
                  title: lesson.title,
                  icon: Icons.school_outlined,
                  accentColor: AikoColors.premiumPurple,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.learningLessonMeta(
                          lesson.category,
                          lesson.estimatedMinutes,
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      InlineGlossaryText(
                        text: lesson.summary,
                        glossary: glossary,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (lesson.quizQuestions.isNotEmpty)
                  progress == LessonProgress.completed
                      ? AikoInlineNotice(
                          title: l10n.learningQuizComplete,
                          message: l10n.learningQuizCompleteMessage,
                          icon: Icons.check_circle_outline,
                          accentColor: AikoColors.successGreen,
                        )
                      : FilledButton.icon(
                          onPressed: () => openAikoPage<void>(
                            context,
                            LessonQuizScreen(lessonKey: lesson.key),
                          ),
                          icon: const Icon(Icons.quiz_outlined),
                          label: Text(l10n.learningTakeQuiz),
                        ),
              ],
            ),
    );
  }
}

/// A lesson's quiz: every question with its options, and feedback on the
/// chosen answer. Answering all of them correctly completes the lesson.
class LessonQuizScreen extends ConsumerStatefulWidget {
  const LessonQuizScreen({required this.lessonKey, super.key});

  final String lessonKey;

  @override
  ConsumerState<LessonQuizScreen> createState() => _LessonQuizScreenState();
}

class _LessonQuizScreenState extends ConsumerState<LessonQuizScreen> {
  /// Question index → chosen option index.
  final _answers = <int, int>{};

  void _answer(Lesson lesson, int question, int option) {
    setState(() => _answers[question] = option);
    if (quizPassed(lesson.quizQuestions, _answers)) {
      ref
          .read(lessonProgressProvider.notifier)
          .record(lesson.key, LessonProgress.completed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lesson = _lessonByKey(widget.lessonKey, l10n);
    final glossary = learningGlossary(l10n);
    final passed = lesson != null && quizPassed(lesson.quizQuestions, _answers);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.learningQuizzes)),
      body: lesson == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text(
                  lesson.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                for (var q = 0; q < lesson.quizQuestions.length; q++)
                  _QuizQuestionCard(
                    question: lesson.quizQuestions[q],
                    glossary: glossary,
                    selected: _answers[q],
                    onSelected: (option) => _answer(lesson, q, option),
                  ),
                if (passed) ...[
                  AikoInlineNotice(
                    title: l10n.learningQuizComplete,
                    message: l10n.learningQuizCompleteMessage,
                    icon: Icons.celebration_outlined,
                    accentColor: AikoColors.successGreen,
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: Text(l10n.close),
                  ),
                ],
              ],
            ),
    );
  }
}

class _QuizQuestionCard extends StatelessWidget {
  const _QuizQuestionCard({
    required this.question,
    required this.glossary,
    required this.selected,
    required this.onSelected,
  });

  final LessonQuizQuestion question;
  final Map<String, String> glossary;
  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final selected = this.selected;
    final correct = selected != null && question.isCorrect(selected);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InlineGlossaryText(
              text: question.prompt,
              glossary: glossary,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < question.options.length; i++)
              _QuizOption(
                label: question.options[i],
                selected: selected == i,
                correct: question.isCorrect(i),
                onTap: () => onSelected(i),
              ),
            if (selected != null) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      correct ? Icons.check_circle : Icons.info_outline,
                      size: 20,
                      color: correct
                          ? AikoColors.successGreen
                          : AikoColors.warningOrange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        correct
                            ? l10n.learningQuizCorrect
                            : l10n.learningQuizIncorrect(
                                question.options[question.correctOptionIndex],
                              ),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuizOption extends StatelessWidget {
  const _QuizOption({
    required this.label,
    required this.selected,
    required this.correct,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool correct;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = !selected
        ? scheme.outlineVariant
        : correct
        ? AikoColors.successGreen
        : AikoColors.warningOrange;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color, width: selected ? 2 : 1),
              color: selected ? color.withValues(alpha: 0.08) : null,
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: selected ? color : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(label)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
