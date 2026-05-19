import 'package:aiko/features/import_export/application/backup_snapshot_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ready backup snapshot with checksum can restore', () {
    final snapshot = const BackupSnapshotService().createReadySnapshot(
      createdAt: DateTime.utc(2026, 5, 19),
      checksum: 'demo-checksum',
    );

    expect(snapshot.canRestore, isTrue);
  });
}
