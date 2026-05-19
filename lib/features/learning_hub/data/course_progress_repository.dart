import '../domain/course_lesson.dart';

class CourseProgressRepository {
  final Map<String, LessonProgress> _progress = {};

  void saveProgress(String lessonKey, LessonProgress progress) {
    _progress[lessonKey] = progress;
  }

  LessonProgress progressFor(String lessonKey) =>
      _progress[lessonKey] ?? LessonProgress.notStarted;
}
