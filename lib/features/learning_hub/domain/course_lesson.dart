enum LessonProgress { notStarted, inProgress, completed }

class CourseLesson {
  const CourseLesson({
    required this.key,
    required this.title,
    required this.category,
    this.summary = '',
    this.estimatedMinutes = 5,
    this.quizQuestions = const [],
    this.progress = LessonProgress.notStarted,
  });

  final String key;
  final String title;
  final String category;
  final String summary;
  final int estimatedMinutes;
  final List<LessonQuizQuestion> quizQuestions;
  final LessonProgress progress;

  double get completionPercent => switch (progress) {
    LessonProgress.notStarted => 0,
    LessonProgress.inProgress => 0.5,
    LessonProgress.completed => 1,
  };
}

class LessonQuizQuestion {
  const LessonQuizQuestion({
    required this.prompt,
    required this.options,
    required this.correctOptionIndex,
  });

  final String prompt;
  final List<String> options;
  final int correctOptionIndex;

  bool isCorrect(int selectedIndex) => selectedIndex == correctOptionIndex;
}
