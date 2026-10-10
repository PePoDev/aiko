import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/layout/adaptive_presentation.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';
import '../application/lesson_progress.dart';
import '../domain/lesson.dart';
import 'inline_glossary_text.dart';
import 'lesson_screens.dart';

class LearningHubScreen extends ConsumerWidget {
  const LearningHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final lessons = lessonsFor(l10n);
    final glossary = learningGlossary(l10n);
    // Progress that can't be read (offline storage error) shows as not
    // started rather than blocking the lessons.
    final progress =
        ref.watch(lessonProgressProvider).value ??
        const <String, LessonProgress>{};
    LessonProgress progressOf(Lesson lesson) =>
        progress[lesson.key] ?? LessonProgress.notStarted;

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
                    _LessonTile(
                      lesson: lesson,
                      glossary: glossary,
                      progress: progressOf(lesson),
                    ),
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
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: InlineGlossaryText(
                        text: l10n.learningQuizSummary(
                          lesson.title,
                          lesson.quizQuestions.length,
                        ),
                        glossary: glossary,
                      ),
                      trailing: progressOf(lesson) == LessonProgress.completed
                          ? Icon(
                              Icons.check_circle,
                              color: AikoColors.successGreen,
                              semanticLabel: l10n.learningProgressCompleted,
                            )
                          : const Icon(Icons.chevron_right),
                      onTap: () => openAikoPage<void>(
                        context,
                        LessonQuizScreen(lessonKey: lesson.key),
                      ),
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
  const _LessonTile({
    required this.lesson,
    required this.glossary,
    required this.progress,
  });

  final Lesson lesson;
  final Map<String, String> glossary;
  final LessonProgress progress;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircularProgressIndicator(
        value: progress.ringValue,
        strokeWidth: 4,
        // A visible track, so a lesson not started reads as an empty ring.
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        semanticsLabel: lessonProgressLabel(progress, context.l10n),
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
      onTap: () =>
          openAikoPage<void>(context, LessonScreen(lessonKey: lesson.key)),
    );
  }
}
