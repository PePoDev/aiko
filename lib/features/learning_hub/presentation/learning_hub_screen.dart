import 'package:flutter/material.dart';

import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';

class LearningHubScreen extends StatelessWidget {
  const LearningHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                  for (final lesson in _lessons) _LessonTile(lesson: lesson),
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
                  for (final lesson in _lessons.where(
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
                  for (final entry in _glossary)
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

  final _Lesson lesson;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircularProgressIndicator(
        value: _completionPercent(lesson.progress),
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

typedef _GlossaryEntry = ({String term, String definition});

enum _LessonProgress { notStarted, inProgress, completed }

double _completionPercent(_LessonProgress progress) => switch (progress) {
  _LessonProgress.notStarted => 0,
  _LessonProgress.inProgress => 0.5,
  _LessonProgress.completed => 1,
};

const _lessons = <_Lesson>[
  (
    key: 'budget-basics',
    title: 'Budgeting without guilt',
    category: 'Budgeting',
    summary:
        'Build a simple plan for needs, wants, goals, and flexible spending.',
    estimatedMinutes: 6,
    progress: _LessonProgress.inProgress,
    quizQuestions: [
      (
        prompt: 'What should a budget help you decide?',
        options: ['Where every dollar goes', 'Which purchases are shameful'],
        correctOptionIndex: 0,
      ),
    ],
  ),
  (
    key: 'emergency-fund',
    title: 'Emergency fund starter plan',
    category: 'Saving',
    summary:
        'Choose a first cushion target and automate a monthly contribution.',
    estimatedMinutes: 5,
    progress: _LessonProgress.notStarted,
    quizQuestions: [
      (
        prompt: 'Why keep an emergency fund separate?',
        options: ['For surprise costs', 'To hide spending'],
        correctOptionIndex: 0,
      ),
    ],
  ),
  (
    key: 'credit-utilization',
    title: 'Credit utilization basics',
    category: 'Credit',
    summary:
        'Understand balance-to-limit ratios and why paydown timing matters.',
    estimatedMinutes: 7,
    progress: _LessonProgress.completed,
    quizQuestions: [
      (
        prompt: 'Lower utilization generally means:',
        options: ['Less available credit', 'A healthier credit signal'],
        correctOptionIndex: 1,
      ),
    ],
  ),
];

const _glossary = <_GlossaryEntry>[
  (term: 'APR', definition: 'Annual percentage rate.'),
  (
    term: 'Safe-to-spend',
    definition: 'Money left after bills, savings, goals, and posted spending.',
  ),
  (
    term: 'Rebalancing',
    definition: 'Adjusting investments back toward target allocation weights.',
  ),
];
