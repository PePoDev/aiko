import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_storage_service.dart';
import '../../../core/storage/synced_preferences.dart';
import '../domain/lesson.dart';

/// Per-lesson progress, kept as the synced preference [storageKey]: a JSON
/// object of lesson key → [LessonProgress] name.
class LessonProgressStore {
  const LessonProgressStore(this._storage);

  static const storageKey = 'learning_progress_v1';

  final SecureStorageService _storage;

  Future<Map<String, LessonProgress>> load() async {
    final raw = await _storage.read(storageKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final byName = LessonProgress.values.asNameMap();
      // Unknown keys or values (e.g. from a newer app version) are skipped.
      return {
        for (final entry in decoded.entries)
          if (entry.key is String) entry.key as String: ?byName[entry.value],
      };
    } on FormatException {
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
    final updated = {...current, lessonKey: next};
    await _storage.write(
      storageKey,
      jsonEncode({
        for (final entry in updated.entries) entry.key: entry.value.name,
      }),
    );
    return updated;
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
/// sees their own progress.
final lessonProgressProvider =
    AsyncNotifierProvider.autoDispose<
      LessonProgressNotifier,
      Map<String, LessonProgress>
    >(LessonProgressNotifier.new);
