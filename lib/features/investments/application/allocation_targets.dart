import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_storage_service.dart';
import '../../../core/storage/synced_preferences.dart';
import '../domain/allocation_target.dart';

/// The share the user wants in each asset class, for rebalance alerts. Kept
/// as the synced preference [storageKey], one item per asset class (its
/// percent), so targets edited on two devices merge. Until targets are first
/// saved they are [defaults].
class AllocationTargetStore {
  const AllocationTargetStore(this._storage);

  static const storageKey = 'allocation_targets_v1';

  static const defaults = [
    AllocationTarget(assetClass: 'Stocks', targetPercent: 70),
    AllocationTarget(assetClass: 'Bonds', targetPercent: 30),
  ];

  final SecureStorageService _storage;

  ItemizedPreference get _preference =>
      ItemizedPreference(_storage, key: storageKey);

  Future<List<AllocationTarget>> load() async =>
      targetsFrom(await _preference.read());

  /// Saves [percents] (asset class → percent; 0 means no target for it) and
  /// returns the targets after the change.
  Future<List<AllocationTarget>> save(Map<String, double> percents) async =>
      targetsFrom(
        await _preference.write({
          for (final MapEntry(:key, :value) in percents.entries)
            key: _format(value),
        }),
      );

  /// The targets in stored [items]: [defaults] when nothing was ever saved,
  /// otherwise every asset class above 0%.
  static List<AllocationTarget> targetsFrom(Map<String, String> items) {
    if (items.isEmpty) return defaults;
    return [
      for (final MapEntry(:key, :value) in items.entries)
        if ((double.tryParse(value) ?? 0) > 0)
          AllocationTarget(assetClass: key, targetPercent: double.parse(value)),
    ];
  }

  static String _format(double percent) => percent == percent.roundToDouble()
      ? percent.toStringAsFixed(0)
      : percent.toString();
}

/// Whether [percents] can be saved: they add up to 100, or are all 0 (no
/// targets, so no rebalance alerts).
bool allocationTargetsValid(Iterable<double> percents) {
  if (percents.any((percent) => percent < 0 || percent > 100)) return false;
  final total = percents.fold<double>(0, (sum, percent) => sum + percent);
  return total == 0 || (total - 100).abs() < 0.001;
}

/// Where allocation targets are stored; overridden in tests.
final allocationTargetsStorageProvider = Provider<SecureStorageService>(
  (ref) => SyncedPreferences(),
);

class AllocationTargetsNotifier extends AsyncNotifier<List<AllocationTarget>> {
  @override
  Future<List<AllocationTarget>> build() =>
      AllocationTargetStore(ref.watch(allocationTargetsStorageProvider)).load();

  /// Saves [percents] (see [AllocationTargetStore.save]); throws when they
  /// can't be stored, keeping the previous targets.
  Future<void> save(Map<String, double> percents) async {
    final saved = await AllocationTargetStore(
      ref.read(allocationTargetsStorageProvider),
    ).save(percents);
    if (ref.mounted) state = AsyncData(saved);
  }
}

/// Reloaded each time a portfolio screen opens, so a different signed-in
/// user sees their own targets. Unreadable storage shows [AllocationTargetStore.defaults].
final allocationTargetsProvider =
    AsyncNotifierProvider.autoDispose<
      AllocationTargetsNotifier,
      List<AllocationTarget>
    >(AllocationTargetsNotifier.new, retry: (_, _) => null);
