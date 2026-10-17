import 'dart:convert';

import '../../../core/storage/secure_storage_service.dart';
import '../../../core/storage/synced_preferences.dart';
import '../domain/app_notification.dart';

/// The notifications the user dismissed, by [AppNotification.id]. Ids carry
/// their period (budget period, bill due date, goal milestone), so a dismissal
/// lasts until the same event comes round again in a new period.
///
/// Stored as one item per dismissed id (its value is when it was dismissed),
/// so dismissals made on two devices while offline both survive.
class NotificationDismissalStore {
  NotificationDismissalStore(this._storage, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  /// The itemized preference (one item per dismissed id).
  static const storageKey = 'dismissed_notifications_v2';

  /// The earlier single JSON list of ids, read until the items are first
  /// written.
  static const legacyKey = 'dismissed_notifications_v1';

  /// Dismissals of notifications that are no longer shown are kept this long,
  /// so one device doesn't drop a dismissal another device made for a
  /// notification it hasn't computed yet.
  static const keepPast = Duration(days: 60);

  final SecureStorageService _storage;
  final DateTime Function() _clock;

  ItemizedPreference get _preference => ItemizedPreference(
    _storage,
    key: storageKey,
    legacyKey: legacyKey,
    legacyItems: _legacyItems,
  );

  /// The dismissed ids; empty when none can be read.
  Future<Set<String>> load() async {
    try {
      return (await _preference.read()).keys.toSet();
    } catch (_) {
      return <String>{};
    }
  }

  /// Adds [id] and returns the new set. Dismissals of ids no longer among
  /// [currentIds] (a past period) are dropped once older than [keepPast], so
  /// the stored list stays small.
  Future<Set<String>> dismiss(String id, Iterable<String> currentIds) async {
    final now = _clock().toUtc();
    final current = currentIds.toSet();
    final stored = await _preference.read();
    final changes = <String, String?>{
      for (final MapEntry(key: dismissed, value: at) in stored.entries)
        if (dismissed != id &&
            !current.contains(dismissed) &&
            _isOlderThan(at, now.subtract(keepPast)))
          dismissed: null,
      id: now.toIso8601String(),
    };
    return (await _preference.write(changes)).keys.toSet();
  }

  /// Whether [dismissedAt] is before [cutoff]; unknown times (earlier
  /// versions stored none) count as old.
  static bool _isOlderThan(String dismissedAt, DateTime cutoff) {
    final at = DateTime.tryParse(dismissedAt);
    return at == null || at.isBefore(cutoff);
  }

  static Map<String, String> _legacyItems(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return {};
    return {
      for (final id in decoded)
        if (id is String) id: '',
    };
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
