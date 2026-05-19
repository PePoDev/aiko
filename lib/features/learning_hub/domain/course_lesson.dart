enum LessonProgress { notStarted, inProgress, completed }

class CourseLesson {
  const CourseLesson({
    required this.key,
    required this.title,
    required this.category,
    this.progress = LessonProgress.notStarted,
  });

  final String key;
  final String title;
  final String category;
  final LessonProgress progress;
}
