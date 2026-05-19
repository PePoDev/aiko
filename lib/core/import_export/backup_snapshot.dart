enum BackupSnapshotStatus { pending, ready, restoring, restored, failed }

class BackupSnapshot {
  const BackupSnapshot({
    required this.status,
    required this.createdAt,
    this.checksum,
  });

  final BackupSnapshotStatus status;
  final DateTime createdAt;
  final String? checksum;

  bool get canRestore =>
      status == BackupSnapshotStatus.ready && checksum != null;
}
