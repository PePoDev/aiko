import '../../../core/import_export/backup_snapshot.dart';

class BackupSnapshotService {
  const BackupSnapshotService();

  BackupSnapshot createReadySnapshot({
    required DateTime createdAt,
    required String checksum,
  }) {
    return BackupSnapshot(
      status: BackupSnapshotStatus.ready,
      createdAt: createdAt,
      checksum: checksum,
    );
  }
}
