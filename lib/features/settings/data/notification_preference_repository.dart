import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/notification_preference.dart';

class NotificationPreferenceRepository {
  const NotificationPreferenceRepository();

  Future<void> save(NotificationPreference preference) async {
    final client = AikoSupabase.tryClient();
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      return;
    }
    try {
      await client.from('notification_preferences').upsert({
        'user_id': user.id,
        'notification_type': preference.type.name,
        'source_module': preference.sourceModule.name,
        'enabled': preference.isEnabled,
      }, onConflict: 'user_id,notification_type');
    } catch (_) {
      return;
    }
  }

  Future<List<NotificationPreference>> listForModule(
    String userId,
    NotificationSourceModule sourceModule,
  ) async {
    final client = AikoSupabase.tryClient();
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      return const [];
    }
    if (userId != user.id) {
      throw StateError(
        'Cannot load notification preferences for another user.',
      );
    }

    final List<dynamic> response;
    try {
      response = await client
          .from('notification_preferences')
          .select()
          .eq('user_id', user.id)
          .eq('source_module', sourceModule.name);
    } catch (_) {
      return const [];
    }

    return response
        .map((row) => _fromRow(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  static NotificationPreference _fromRow(Map<String, dynamic> row) {
    final type = NotificationType.values.firstWhere(
      (item) => item.name == row['notification_type'],
      orElse: () => NotificationType.aikoReviewReady,
    );
    final sourceModule = NotificationSourceModule.values.firstWhere(
      (item) => item.name == (row['source_module'] as String? ?? 'reports'),
      orElse: () => NotificationSourceModule.reports,
    );

    return NotificationPreference(
      userId: row['user_id'] as String,
      type: type,
      sourceModule: sourceModule,
      isEnabled: row['enabled'] as bool? ?? true,
    );
  }
}
