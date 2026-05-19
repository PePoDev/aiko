import '../domain/course_lesson.dart';

class LessonRecommendationService {
  const LessonRecommendationService();

  CourseLesson recommend(List<CourseLesson> lessons, String category) {
    return lessons.firstWhere(
      (lesson) =>
          lesson.category == category &&
          lesson.progress != LessonProgress.completed,
      orElse: () => lessons.first,
    );
  }
}
