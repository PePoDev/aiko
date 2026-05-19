import 'package:aiko/core/sync/sync_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sync state needs attention for failed sync', () {
    const state = DeviceSyncState(
      deviceId: 'phone-1',
      status: SyncStatus.failed,
    );

    expect(state.needsUserAttention, isTrue);
  });

  test('sync state needs attention for unresolved conflicts', () {
    const state = DeviceSyncState(
      deviceId: 'tablet-1',
      status: SyncStatus.synced,
      conflictStatus: SyncConflictStatus.needsReview,
    );

    expect(state.needsUserAttention, isTrue);
  });
}
