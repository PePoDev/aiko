import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/course_lesson.dart';

class CourseProgressRepository {
  const CourseProgressRepository();

  Future<void> saveProgress(String lessonKey, LessonProgress progress) async {
    final session = AikoSupabase.requireSession();
    await session.client.from('course_lessons').upsert({
      'user_id': session.userId,
      'lesson_key': lessonKey,
      'title': lessonKey,
      'category': 'general',
      'progress_status': progress.name,
    }, onConflict: 'user_id,lesson_key');
  }

  Future<LessonProgress> progressFor(String lessonKey) async {
    final session = AikoSupabase.requireSession();
    final row = await session.client
        .from('course_lessons')
        .select('progress_status')
        .eq('user_id', session.userId)
        .eq('lesson_key', lessonKey)
        .maybeSingle();

    if (row == null) {
      return LessonProgress.notStarted;
    }

    return LessonProgress.values.firstWhere(
      (item) => item.name == row['progress_status'],
      orElse: () => LessonProgress.notStarted,
    );
  }
}
