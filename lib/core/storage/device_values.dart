import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_record_store.dart';

/// Small values that belong to this device only and are never synced: the
/// last exchange rates, when prices were last refreshed, the last known LINE
/// status. Losing them only costs a refetch, so reads and writes never throw.
abstract interface class DeviceValueStore {
  /// The value saved under [key], or null (also when it can't be read).
  Future<String?> read(String key);

  /// Saves [value] under [key]; does nothing when it can't be saved.
  Future<void> write(String key, String value);
}

/// [DeviceValueStore] in the local record store's `meta` table (SQLite, or
/// IndexedDB on the web). Before the app has opened that store, reads return
/// null and writes are skipped.
class LocalDeviceValues implements DeviceValueStore {
  const LocalDeviceValues({LocalRecordStore? store}) : _store = store;

  final LocalRecordStore? _store;

  static const _prefix = 'device:';

  LocalRecordStore? get _open =>
      _store ?? (LocalRecordStore.isOpen ? LocalRecordStore.instance : null);

  @override
  Future<String?> read(String key) async {
    try {
      return await _open?.meta('$_prefix$key');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _open?.transaction((txn) => txn.setMeta('$_prefix$key', value));
    } catch (_) {
      // A cache, not data: the next successful fetch writes it again.
    }
  }
}

/// [DeviceValueStore] in memory, for tests.
class MemoryDeviceValues implements DeviceValueStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

/// This device's [DeviceValueStore]; overridden in tests.
final deviceValuesProvider = Provider<DeviceValueStore>(
  (ref) => const LocalDeviceValues(),
);
