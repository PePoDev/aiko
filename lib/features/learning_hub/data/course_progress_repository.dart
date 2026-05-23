import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/course_lesson.dart';

class CourseProgressRepository {
  const CourseProgressRepository();

  Future<void> saveProgress(String lessonKey, LessonProgress progress) async {
    final client = AikoSupabase.tryClient();
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      return;
    }
    try {
      await client.from('course_lessons').upsert({
        'user_id': user.id,
        'lesson_key': lessonKey,
        'title': lessonKey,
        'category': 'general',
        'progress_status': progress.name,
      }, onConflict: 'user_id,lesson_key');
    } catch (_) {
      return;
    }
  }

  Future<LessonProgress> progressFor(String lessonKey) async {
    final client = AikoSupabase.tryClient();
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      return LessonProgress.notStarted;
    }
    final Map<String, dynamic>? row;
    try {
      row = await client
          .from('course_lessons')
          .select('progress_status')
          .eq('user_id', user.id)
          .eq('lesson_key', lessonKey)
          .maybeSingle();
    } catch (_) {
      return LessonProgress.notStarted;
    }

    if (row == null) {
      return LessonProgress.notStarted;
    }

    final progressStatus = row['progress_status'] as String?;
    return LessonProgress.values.firstWhere(
      (item) => item.name == progressStatus,
      orElse: () => LessonProgress.notStarted,
    );
  }
}
