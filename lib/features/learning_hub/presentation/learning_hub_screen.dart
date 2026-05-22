import 'package:flutter/material.dart';

import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';
import '../application/learning_hub_catalog.dart';
import '../domain/course_lesson.dart';

class LearningHubScreen extends StatelessWidget {
  const LearningHubScreen({super.key});

  static const _catalog = LearningHubCatalog();

  @override
  Widget build(BuildContext context) {
    final lessons = _catalog.recommendedLessons();
    final glossary = _catalog.glossary();

    return Scaffold(
      appBar: AppBar(title: const Text('Learning Hub')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FinanceCard(
              title: 'Recommended lessons',
              icon: Icons.school_outlined,
              accentColor: AikoColors.premiumPurple,
              prominent: true,
              child: Column(
                children: [
                  for (final lesson in lessons) _LessonTile(lesson: lesson),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FinanceCard(
              title: 'Quizzes',
              icon: Icons.quiz_outlined,
              accentColor: AikoColors.deepBlue,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final lesson in lessons.where(
                    (lesson) => lesson.quizQuestions.isNotEmpty,
                  ))
                    Text(
                      '${lesson.title}: ${lesson.quizQuestions.length} question quiz',
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FinanceCard(
              title: 'Glossary',
              icon: Icons.menu_book_outlined,
              accentColor: AikoColors.analyticsTeal,
              child: Column(
                children: [
                  for (final entry in glossary)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry.term),
                      subtitle: Text(entry.definition),
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
  const _LessonTile({required this.lesson});

  final CourseLesson lesson;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircularProgressIndicator(
        value: lesson.completionPercent,
        strokeWidth: 4,
      ),
      title: Text(lesson.title),
      subtitle: Text(
        '${lesson.category} - ${lesson.estimatedMinutes} min\n${lesson.summary}',
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
