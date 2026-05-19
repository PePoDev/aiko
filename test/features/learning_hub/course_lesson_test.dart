import 'package:aiko/features/learning_hub/application/lesson_recommendation_service.dart';
import 'package:aiko/features/learning_hub/data/course_progress_repository.dart';
import 'package:aiko/features/learning_hub/domain/course_lesson.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recommends unfinished lesson and records progress', () {
    const lesson = CourseLesson(
      key: 'budgeting',
      title: 'Budgeting Basics',
      category: 'budgeting',
    );
    final repo = CourseProgressRepository();

    expect(
      const LessonRecommendationService().recommend([lesson], 'budgeting').key,
      'budgeting',
    );
    repo.saveProgress('budgeting', LessonProgress.completed);
    expect(repo.progressFor('budgeting'), LessonProgress.completed);
  });
}
