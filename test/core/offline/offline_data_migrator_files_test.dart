import 'package:aiko/core/offline/offline_data_migrator.dart';
import 'package:aiko/core/offline/offline_store.dart';
import 'package:aiko/core/storage/local_record_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'record_store_harness.dart';

void main() {
  late LocalRecordStore local;

  setUp(() async => local = await openMemoryRecordStore());
  tearDown(() => local.close());

  test('claiming guest data hands over guest files too', () async {
    final claimedFor = <String>[];
    final migrator = OfflineDataMigrator(
      store: OfflineStore(local: local, signedInUserId: () => null),
      claimFiles: (userId) async {
        claimedFor.add(userId);
        return 2;
      },
    );

    expect(await migrator.claimAnonymousData('uid-1'), 2);
    expect(claimedFor, ['uid-1']);

    // A guest id is never a claim target.
    expect(await migrator.claimAnonymousData('local:other'), 0);
    expect(claimedFor, ['uid-1']);
  });
}
