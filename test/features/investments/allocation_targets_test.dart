import 'package:aiko/core/storage/secure_storage_service.dart';
import 'package:aiko/features/investments/application/allocation_targets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('targets are 70% stocks and 30% bonds until first saved', () async {
    final targets = await AllocationTargetStore(
      MemorySecureStorageService(),
    ).load();
    expect(
      {for (final t in targets) t.assetClass: t.targetPercent},
      {'Stocks': 70, 'Bonds': 30},
    );
  });

  test('saved targets replace the defaults and 0% means no target', () async {
    final store = AllocationTargetStore(MemorySecureStorageService());
    await store.save({'Stocks': 60, 'Bonds': 0, 'Funds': 40});
    final targets = await store.load();
    expect(
      {for (final t in targets) t.assetClass: t.targetPercent},
      {'Stocks': 60, 'Funds': 40},
    );
  });

  test('saving all 0% turns the targets off', () async {
    final store = AllocationTargetStore(MemorySecureStorageService());
    await store.save({'Stocks': 0, 'Bonds': 0});
    expect(await store.load(), isEmpty);
  });

  test('targets must add up to 100 or all be 0', () {
    expect(allocationTargetsValid([70, 30]), isTrue);
    expect(allocationTargetsValid([33.3, 33.3, 33.4]), isTrue);
    expect(allocationTargetsValid([0, 0]), isTrue);
    expect(allocationTargetsValid([60, 30]), isFalse);
    expect(allocationTargetsValid([120, -20]), isFalse);
  });
}
