import '../domain/course_lesson.dart';
import '../domain/glossary_entry.dart';
import '../domain/quiz_result.dart';

class LearningHubCatalog {
  const LearningHubCatalog();

  List<CourseLesson> recommendedLessons() {
    return const [
      CourseLesson(
        key: 'budget-basics',
        title: 'Budgeting without guilt',
        category: 'Budgeting',
        summary:
            'Build a simple plan for needs, wants, goals, and flexible spending.',
        estimatedMinutes: 6,
        progress: LessonProgress.inProgress,
        quizQuestions: [
          LessonQuizQuestion(
            prompt: 'What should a budget help you decide?',
            options: [
              'Where every dollar goes',
              'Which purchases are shameful',
            ],
            correctOptionIndex: 0,
          ),
        ],
      ),
      CourseLesson(
        key: 'emergency-fund',
        title: 'Emergency fund starter plan',
        category: 'Saving',
        summary:
            'Choose a first cushion target and automate a monthly contribution.',
        estimatedMinutes: 5,
        quizQuestions: [
          LessonQuizQuestion(
            prompt: 'Why keep an emergency fund separate?',
            options: ['For surprise costs', 'To hide spending'],
            correctOptionIndex: 0,
          ),
        ],
      ),
      CourseLesson(
        key: 'credit-utilization',
        title: 'Credit utilization basics',
        category: 'Credit',
        summary:
            'Understand balance-to-limit ratios and why paydown timing matters.',
        estimatedMinutes: 7,
        progress: LessonProgress.completed,
        quizQuestions: [
          LessonQuizQuestion(
            prompt: 'Lower utilization generally means:',
            options: ['Less available credit', 'A healthier credit signal'],
            correctOptionIndex: 1,
          ),
        ],
      ),
    ];
  }

  List<GlossaryEntry> glossary() {
    return const [
      GlossaryEntry(term: 'APR', definition: 'Annual percentage rate.'),
      GlossaryEntry(
        term: 'Safe-to-spend',
        definition:
            'Money left after bills, savings, goals, and posted spending.',
      ),
      GlossaryEntry(
        term: 'Rebalancing',
        definition:
            'Adjusting investments back toward target allocation weights.',
      ),
    ];
  }

  QuizResult score(CourseLesson lesson, List<int> selectedIndexes) {
    var correct = 0;
    for (var index = 0; index < lesson.quizQuestions.length; index++) {
      if (index < selectedIndexes.length &&
          lesson.quizQuestions[index].isCorrect(selectedIndexes[index])) {
        correct++;
      }
    }
    return QuizResult(correct: correct, total: lesson.quizQuestions.length);
  }
}
