import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../offline/firestore_sync_state.dart';
import '../storage/file_sync_queue.dart';
import '../storage/secure_storage_service.dart';
import 'network_status.dart';

/// What the user should know about their data's sync.
@immutable
class SyncStatus {
  const SyncStatus({
    this.offline = false,
    this.signedIn = false,
    this.syncing = false,
    this.lastSyncedAt,
  });

  /// The device reports no network connection.
  final bool offline;

  /// Changes sync through the user's account (Firestore). Guests and
  /// local-only builds keep everything on the device.
  final bool signedIn;

  /// Signed-in changes, or files (attachments, the profile photo), have
  /// been waiting to upload for a moment (a write that the server
  /// acknowledges straight away isn't worth a message). Files whose upload
  /// failed for good until the next launch don't count; they are reported
  /// when they fail.
  final bool syncing;

  /// The last time everything was known to be in sync with the server.
  final DateTime? lastSyncedAt;

  @override
  bool operator ==(Object other) =>
      other is SyncStatus &&
      other.offline == offline &&
      other.signedIn == signedIn &&
      other.syncing == syncing &&
      other.lastSyncedAt == lastSyncedAt;

  @override
  int get hashCode => Object.hash(offline, signedIn, syncing, lastSyncedAt);
}

/// The status line to show, if any.
enum SyncBanner {
  /// Signed in and offline: changes are kept and upload later.
  offline,

  /// A guest or local-only build offline: only network features are out.
  offlineLocal,

  /// Online, and signed-in changes or files are still uploading.
  syncing,
}

/// The banner for [status]; null when everything is in sync. Guests and
/// local-only builds never see "syncing" (nothing of theirs uploads).
SyncBanner? syncBannerFor(SyncStatus status) {
  if (status.offline) {
    return status.signedIn ? SyncBanner.offline : SyncBanner.offlineLocal;
  }
  if (status.signedIn && status.syncing) return SyncBanner.syncing;
  return null;
}

/// The app's [FirestoreSyncState]; overridden in tests.
final firestoreSyncStateProvider = Provider<FirestoreSyncState>(
  (ref) => FirestoreSyncState.instance,
);

/// The app's [FileSyncQueue]; overridden in tests.
final fileSyncQueueProvider = Provider<FileSyncQueue>(
  (ref) => FileSyncQueue.instance,
);

/// Where the last sync time is remembered between launches; overridden in
/// tests.
final syncStatusStorageProvider = Provider<SecureStorageService>(
  (ref) => FlutterSecureStorageService(),
);

/// Whether the device is offline, whether signed-in changes or files are
/// waiting to upload, and when everything was last in sync.
final syncStatusProvider = NotifierProvider<SyncStatusNotifier, SyncStatus>(
  SyncStatusNotifier.new,
);

class SyncStatusNotifier extends Notifier<SyncStatus> {
  SyncStatusNotifier({this.syncingDelay = const Duration(seconds: 2)});

  /// How long changes wait to upload before "Syncing…" is shown.
  final Duration syncingDelay;

  /// The remembered last sync time is rewritten at most this often.
  static const _rememberEvery = Duration(minutes: 1);

  Timer? _syncingTimer;
  DateTime? _remembered;
  String? _rememberedFor;
  var _online = true;

  /// Whether files of [_filesFor] are waiting to upload (not counting ones
  /// that failed for good), as last counted.
  var _filesWaiting = false;
  String? _filesFor;

  /// The user and number of the latest count of files.
  String? _countingFor;
  var _fileCount = 0;

  @override
  SyncStatus build() {
    final sync = ref.watch(firestoreSyncStateProvider);
    final files = ref.watch(fileSyncQueueProvider);
    final online = ref.watch(deviceOnlineProvider).value ?? true;
    _online = online;
    // Reads skip the network while the device has none.
    sync.deviceOffline = !online;
    final subscription = sync.changes.listen((_) {
      _update(sync);
      // Signed in or out: count the new user's files.
      if (sync.userId != _countingFor) unawaited(_countFiles(sync, files));
    });
    final fileChanges = files.changes.listen(
      (_) => unawaited(_countFiles(sync, files)),
    );
    ref.onDispose(() {
      subscription.cancel();
      fileChanges.cancel();
      _syncingTimer?.cancel();
    });
    final status = _statusOf(sync, syncing: false);
    _syncingTimer?.cancel();
    _syncingTimer = null;
    if (_hasPending(sync)) _startSyncingTimer(sync);
    unawaited(_restoreRemembered(sync));
    unawaited(_countFiles(sync, files));
    return status;
  }

  bool _hasPending(FirestoreSyncState sync) =>
      sync.hasPendingWrites ||
      (_filesWaiting && _filesFor != null && _filesFor == sync.userId);

  SyncStatus _statusOf(FirestoreSyncState sync, {required bool syncing}) =>
      SyncStatus(
        offline: !_online,
        signedIn: sync.userId != null,
        syncing: syncing && _hasPending(sync),
        lastSyncedAt: sync.lastSyncedAt ?? _rememberedAt(sync),
      );

  void _update(FirestoreSyncState sync) {
    if (!ref.mounted) return;
    if (!_hasPending(sync)) {
      _syncingTimer?.cancel();
      _syncingTimer = null;
    } else if (_syncingTimer == null && !state.syncing) {
      _startSyncingTimer(sync);
    }
    state = _statusOf(sync, syncing: state.syncing);
    unawaited(_remember(sync));
  }

  /// Counts the signed-in user's files waiting to upload, and updates the
  /// status when that changes whether any are.
  Future<void> _countFiles(FirestoreSyncState sync, FileSyncQueue files) async {
    final ticket = ++_fileCount;
    final uid = _countingFor = sync.userId;
    var waiting = false;
    if (uid != null) {
      try {
        final counts = await files.counts(uid);
        waiting = counts.pending > counts.failed;
      } catch (_) {
        // No file database here: nothing of theirs is waiting.
      }
    }
    if (!ref.mounted || ticket != _fileCount) return;
    final changed = waiting != _filesWaiting || uid != _filesFor;
    _filesWaiting = waiting;
    _filesFor = uid;
    if (changed) _update(sync);
  }

  void _startSyncingTimer(FirestoreSyncState sync) {
    _syncingTimer = Timer(syncingDelay, () {
      _syncingTimer = null;
      if (!ref.mounted) return;
      state = _statusOf(sync, syncing: true);
    });
  }

  DateTime? _rememberedAt(FirestoreSyncState sync) =>
      _rememberedFor != null && _rememberedFor == sync.userId
      ? _remembered
      : null;

  String _storageKey(String uid) => '$uid:sync_last_synced_at';

  /// Shows the last sync time saved by an earlier launch until this one has
  /// been in sync (an offline start).
  Future<void> _restoreRemembered(FirestoreSyncState sync) async {
    final uid = sync.userId;
    if (uid == null || _rememberedFor == uid) return;
    try {
      final raw = await ref
          .read(syncStatusStorageProvider)
          .read(_storageKey(uid));
      final at = raw == null ? null : DateTime.tryParse(raw);
      if (at == null || !ref.mounted || sync.userId != uid) return;
      if (_rememberedFor == uid) return;
      _remembered = at;
      _rememberedFor = uid;
      state = _statusOf(sync, syncing: state.syncing);
    } catch (_) {
      // Unknown until the next sync.
    }
  }

  Future<void> _remember(FirestoreSyncState sync) async {
    final uid = sync.userId;
    final at = sync.lastSyncedAt;
    if (uid == null || at == null) return;
    final previous = _rememberedAt(sync);
    if (previous != null && at.difference(previous) < _rememberEvery) return;
    _remembered = at;
    _rememberedFor = uid;
    try {
      await ref
          .read(syncStatusStorageProvider)
          .write(_storageKey(uid), at.toUtc().toIso8601String());
    } catch (_) {
      // Best effort.
    }
  }
}
