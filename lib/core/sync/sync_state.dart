enum SyncStatus { idle, syncing, synced, failed }

enum SyncConflictStatus { none, needsReview, resolved }

class DeviceSyncState {
  const DeviceSyncState({
    required this.deviceId,
    required this.status,
    this.conflictStatus = SyncConflictStatus.none,
    this.lastSyncedAt,
    this.isCurrentDevice = false,
  });

  final String deviceId;
  final SyncStatus status;
  final SyncConflictStatus conflictStatus;
  final DateTime? lastSyncedAt;
  final bool isCurrentDevice;

  bool get needsUserAttention =>
      status == SyncStatus.failed ||
      conflictStatus == SyncConflictStatus.needsReview;
}
