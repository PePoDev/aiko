import 'package:aiko/features/learning_hub/application/lesson_recommendation_service.dart';
import 'package:aiko/features/learning_hub/data/course_progress_repository.dart';
import 'package:aiko/features/learning_hub/domain/course_lesson.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recommends unfinished lesson', () {
    const lesson = CourseLesson(
      key: 'budgeting',
      title: 'Budgeting Basics',
      category: 'budgeting',
    );

    expect(
      const LessonRecommendationService().recommend([lesson], 'budgeting').key,
      'budgeting',
    );
  });

  test('course progress repository falls back offline', () async {
    const repo = CourseProgressRepository();

    await repo.saveProgress('budgeting', LessonProgress.completed);
    expect(await repo.progressFor('budgeting'), LessonProgress.notStarted);
  });
}
