import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_storage_service.dart';
import '../../../core/storage/synced_preferences.dart';
import '../domain/lesson.dart';

/// Per-lesson progress, kept as the synced itemized preference [storageKey]:
/// one item per lesson and level reached (`<lesson key>:<level name>`). Items
/// are only ever added, and a lesson's progress is its highest level, so
/// progress made on two devices while offline merges and never goes back.
class LessonProgressStore {
  const LessonProgressStore(this._storage);

  static const storageKey = 'learning_progress_v2';

  /// The earlier JSON object of lesson key → level name, read until the items
  /// are first written.
  static const legacyKey = 'learning_progress_v1';

  final SecureStorageService _storage;

  ItemizedPreference get _preference => ItemizedPreference(
    _storage,
    key: storageKey,
    legacyKey: legacyKey,
    legacyItems: _legacyItems,
  );

  /// Progress by lesson key; empty when none can be read.
  Future<Map<String, LessonProgress>> load() async {
    try {
      return _progressOf(await _preference.read());
    } catch (_) {
      return {};
    }
  }

  /// Raises [lessonKey] to at least [progress] (never lowers it) and returns
  /// the updated map.
  Future<Map<String, LessonProgress>> record(
    String lessonKey,
    LessonProgress progress,
  ) async {
    final current = await load();
    final previous = current[lessonKey] ?? LessonProgress.notStarted;
    final next = previous.atLeast(progress);
    if (next == previous && current.containsKey(lessonKey)) return current;
    return _progressOf(
      await _preference.write({_itemKey(lessonKey, next): ''}),
    );
  }

  static String _itemKey(String lessonKey, LessonProgress level) =>
      '$lessonKey:${level.name}';

  /// The highest level per lesson. Unknown levels (e.g. from a newer app
  /// version) are skipped.
  static Map<String, LessonProgress> _progressOf(Map<String, String> items) {
    final byName = LessonProgress.values.asNameMap();
    final progress = <String, LessonProgress>{};
    for (final item in items.keys) {
      final separator = item.lastIndexOf(':');
      if (separator <= 0) continue;
      final level = byName[item.substring(separator + 1)];
      if (level == null) continue;
      final lessonKey = item.substring(0, separator);
      progress[lessonKey] = (progress[lessonKey] ?? level).atLeast(level);
    }
    return progress;
  }

  static Map<String, String> _legacyItems(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    final byName = LessonProgress.values.asNameMap();
    return {
      for (final MapEntry(:key, :value) in decoded.entries)
        if (key is String && byName[value] != null)
          _itemKey(key, byName[value]!): '',
    };
  }
}

/// Where lesson progress is stored; overridden in tests.
final lessonProgressStorageProvider = Provider<SecureStorageService>(
  (ref) => SyncedPreferences(),
);

class LessonProgressNotifier
    extends AsyncNotifier<Map<String, LessonProgress>> {
  @override
  Future<Map<String, LessonProgress>> build() =>
      LessonProgressStore(ref.watch(lessonProgressStorageProvider)).load();

  Future<void> record(String lessonKey, LessonProgress progress) async {
    final store = LessonProgressStore(ref.read(lessonProgressStorageProvider));
    Map<String, LessonProgress> current;
    try {
      // Wait for the stored progress so this doesn't race the first load.
      current = await future;
    } catch (_) {
      current = const {};
    }
    final previous = current[lessonKey] ?? LessonProgress.notStarted;
    final next = previous.atLeast(progress);
    if (!ref.mounted || (next == previous && current.containsKey(lessonKey))) {
      return;
    }
    // Show it straight away; the write follows.
    state = AsyncData({...current, lessonKey: next});
    try {
      final saved = await store.record(lessonKey, progress);
      if (ref.mounted) state = AsyncData(saved);
    } catch (_) {
      // Keep the in-memory progress for this session if storage fails.
    }
  }
}

/// Reloaded each time the Learning Hub opens, so a different signed-in user
/// sees their own progress. Never retried: storage that can't be read shows
/// no progress straight away instead of a spinner.
final lessonProgressProvider =
    AsyncNotifierProvider.autoDispose<
      LessonProgressNotifier,
      Map<String, LessonProgress>
    >(LessonProgressNotifier.new, retry: (_, _) => null);
