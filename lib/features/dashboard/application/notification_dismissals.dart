import 'dart:convert';

import '../../../core/storage/secure_storage_service.dart';
import '../domain/app_notification.dart';

/// The notifications the user dismissed, by [AppNotification.id]. Ids carry
/// their period (budget period, bill due date, goal milestone), so a dismissal
/// lasts until the same event comes round again in a new period.
class NotificationDismissalStore {
  const NotificationDismissalStore(this._storage);

  static const storageKey = 'dismissed_notifications_v1';

  final SecureStorageService _storage;

  Future<Set<String>> load() async {
    final raw = await _storage.read(storageKey);
    if (raw == null || raw.isEmpty) return <String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <String>{};
      return {
        for (final id in decoded)
          if (id is String) id,
      };
    } on FormatException {
      return <String>{};
    }
  }

  /// Adds [id] and returns the new set. Ids no longer among [currentIds] (a
  /// past period) are dropped, so the stored list stays small.
  Future<Set<String>> dismiss(String id, Iterable<String> currentIds) async {
    final current = currentIds.toSet();
    final next = {
      for (final dismissed in await load())
        if (current.contains(dismissed)) dismissed,
      id,
    };
    await _storage.write(storageKey, jsonEncode(next.toList()..sort()));
    return next;
  }
}

/// [notifications] without the ones in [dismissed].
List<AppNotification> withoutDismissed(
  List<AppNotification> notifications,
  Set<String> dismissed,
) => [
  for (final notification in notifications)
    if (!dismissed.contains(notification.id)) notification,
];
