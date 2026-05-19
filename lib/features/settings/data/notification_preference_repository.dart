import '../domain/notification_preference.dart';

class NotificationPreferenceRepository {
  final List<NotificationPreference> _preferences = [];

  Future<void> save(NotificationPreference preference) async {
    _preferences.removeWhere(
      (item) =>
          item.userId == preference.userId && item.type == preference.type,
    );
    _preferences.add(preference);
  }

  Future<List<NotificationPreference>> listForModule(
    String userId,
    NotificationSourceModule sourceModule,
  ) async {
    return _preferences
        .where(
          (item) => item.userId == userId && item.sourceModule == sourceModule,
        )
        .toList(growable: false);
  }
}
