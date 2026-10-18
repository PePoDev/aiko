import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../firebase/firebase_backend.dart';
import '../offline/firestore_sync_state.dart';
import '../offline/offline_store.dart';
import 'secure_storage_service.dart';

/// What a read of an itemized preference learned: its [items] (null when
/// never written), and whether this device could tell at all ([known] is
/// false signed in and offline, with nothing cached).
typedef PreferenceItemsRead = ({Map<String, String>? items, bool known});

/// Storage that keeps a preference as independent items (item key → value),
/// for lists that several devices may change while offline: a change writes
/// only its own items, so changes to different items all survive.
abstract interface class PreferenceItemStorage {
  /// The items of [key], or null when it has never been written (or, signed
  /// in and offline, this device can't tell).
  Future<Map<String, String>?> readItems(String key);

  /// Like [readItems], telling "never written" apart from "can't tell".
  Future<PreferenceItemsRead> readItemsState(String key);

  /// Sets the items of [changes] that have a value and removes those mapped
  /// to null, leaving every other item of [key] as it is.
  Future<void> writeItems(String key, Map<String, String?> changes);

  /// Changes to [key] kept on this device until a read can tell whether its
  /// items were ever written ([ItemizedPreference.write]); null when none.
  Future<Map<String, String?>?> readDeferred(String key);

  /// Replaces the changes kept for [key]; null drops them.
  Future<void> writeDeferred(String key, Map<String, String?>? changes);
}

/// [PreferenceItemStorage] over device storage: the items are one JSON object
/// stored under the key. Only this device writes it, so read-modify-write is
/// safe, and it always knows whether the items exist.
class DevicePreferenceItems implements PreferenceItemStorage {
  const DevicePreferenceItems(this._storage);

  final SecureStorageService _storage;

  @override
  Future<Map<String, String>?> readItems(String key) async {
    final raw = await _storage.read(key);
    if (raw == null) return null;
    return decodePreferenceItems(raw) ?? {};
  }

  @override
  Future<PreferenceItemsRead> readItemsState(String key) async =>
      (items: await readItems(key), known: true);

  @override
  Future<void> writeItems(String key, Map<String, String?> changes) async {
    final items = {...?await readItems(key)};
    applyPreferenceItemChanges(items, changes);
    await _storage.write(key, jsonEncode(items));
  }

  @override
  Future<Map<String, String?>?> readDeferred(String key) async => null;

  @override
  Future<void> writeDeferred(String key, Map<String, String?>? changes) async {}
}

/// The items stored as a JSON object in [raw]; null when it isn't one. Values
/// that aren't strings are skipped.
Map<String, String>? decodePreferenceItems(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return _stringItems(decoded);
  } on FormatException {
    return null;
  }
}

Map<String, String> _stringItems(Map<Object?, Object?> items) => {
  for (final entry in items.entries)
    if (entry.key case final String key)
      if (entry.value case final String value) key: value,
};

/// Applies [changes] to [items]: a value sets the item, null removes it.
void applyPreferenceItemChanges(
  Map<String, String> items,
  Map<String, String?> changes,
) {
  for (final MapEntry(:key, :value) in changes.entries) {
    if (value == null) {
      items.remove(key);
    } else {
      items[key] = value;
    }
  }
}

/// A list-like preference kept as items ([PreferenceItemStorage]) instead of
/// one JSON value, so changes made on several devices while offline merge
/// instead of replacing each other.
///
/// [legacyKey] is the single-value preference it replaces: until the items
/// are first written they are read from it ([legacyItems] converts its value),
/// and the first write carries them over. The legacy value is left in place
/// for app versions that still read it.
///
/// Carrying over needs to know that the items were never written: another
/// device may have written (and since changed) them already. While this
/// device can't tell (signed in and offline, nothing cached), changes wait on
/// the device and show on top of the legacy items; the first read or write
/// that can tell writes them.
class ItemizedPreference {
  ItemizedPreference(
    SecureStorageService storage, {
    required this.key,
    this.legacyKey,
    this.legacyItems,
  }) : _storage = storage,
       _items = storage is PreferenceItemStorage
           ? storage as PreferenceItemStorage
           : DevicePreferenceItems(storage);

  final SecureStorageService _storage;
  final PreferenceItemStorage _items;
  final String key;
  final String? legacyKey;
  final Map<String, String> Function(String legacyValue)? legacyItems;

  /// The current items (empty when there are none).
  Future<Map<String, String>> read() async {
    final stored = await _items.readItemsState(key);
    final deferred = await _items.readDeferred(key);
    if (deferred == null) return stored.items ?? await _legacy();
    if (stored.known) {
      return _writeKnown(stored.items, deferred, hadDeferred: true);
    }
    return _withChanges(await _legacy(), deferred);
  }

  /// Writes [changes] (null removes an item) and returns the items after them.
  Future<Map<String, String>> write(Map<String, String?> changes) async {
    final stored = await _items.readItemsState(key);
    final deferred = await _items.readDeferred(key);
    final pending = {...?deferred, ...changes};
    if (stored.known) {
      return _writeKnown(stored.items, pending, hadDeferred: deferred != null);
    }
    // Whether the items exist is unknown: carrying the legacy items over now
    // could bring back items another device removed (or undo its edits),
    // and writing only the changes would hide the legacy items for good.
    await _items.writeDeferred(key, pending);
    return _withChanges(await _legacy(), pending);
  }

  /// Writes [changes] now that it is known whether the items exist ([stored]
  /// is null when they were never written), then drops deferred changes.
  Future<Map<String, String>> _writeKnown(
    Map<String, String>? stored,
    Map<String, String?> changes, {
    required bool hadDeferred,
  }) async {
    final current = stored ?? await _legacy();
    // The first write carries the legacy items over.
    final toWrite = stored == null
        ? <String, String?>{...current, ...changes}
        : changes;
    if (toWrite.isNotEmpty) await _items.writeItems(key, toWrite);
    if (hadDeferred) await _items.writeDeferred(key, null);
    return _withChanges(current, changes);
  }

  static Map<String, String> _withChanges(
    Map<String, String> items,
    Map<String, String?> changes,
  ) {
    final next = {...items};
    applyPreferenceItemChanges(next, changes);
    return next;
  }

  Future<Map<String, String>> _legacy() async {
    final legacyKey = this.legacyKey;
    final convert = legacyItems;
    if (legacyKey == null || convert == null) return {};
    try {
      final raw = await _storage.read(legacyKey);
      return raw == null || raw.isEmpty ? {} : convert(raw);
    } catch (_) {
      return {};
    }
  }
}

/// Only explicit user preferences are shared; auth keys and OS permissions
/// always remain in device storage.
///
/// Signed in, each preference is the document `preferences/<key>`: a single
/// `value`, or `items` for an [ItemizedPreference] (written field by field
/// with merges). Reads come from the Firestore cache; when it doesn't know a
/// document (offline right after sign-in, or a reinstall that kept the
/// session), they use this device's copy (`<uid>:<key>` in device storage,
/// kept in step with every read and write), and ask the server only briefly
/// ([FirestoreSyncState]). A preference nobody can find is "no value"; reads
/// never fail because the device is offline.
class SyncedPreferences implements SecureStorageService, PreferenceItemStorage {
  /// [local], [firestore], [userId] and [sync] default to device storage,
  /// Firebase, the Firebase user and the app's sync state; tests replace them.
  SyncedPreferences({
    SecureStorageService? local,
    FirebaseFirestore? firestore,
    String? Function()? userId,
    FirestoreSyncState? sync,
  }) : _local = local ?? FlutterSecureStorageService(),
       _firestore = firestore,
       _userId = userId ?? (() => FirebaseBackend.userId),
       _sync = sync ?? FirestoreSyncState.instance;

  final SecureStorageService _local;
  final FirebaseFirestore? _firestore;
  final String? Function() _userId;
  final FirestoreSyncState _sync;

  static const _collection = 'preferences';

  /// Stored as this device's copy of a preference known not to exist.
  static const _missing = '\u0000';

  String? get _uid {
    final uid = _userId();
    return uid == null || uid.isEmpty ? null : uid;
  }

  String _copyKey(String uid, String key) => '$uid:$key';

  DocumentReference<Map<String, dynamic>> _doc(String uid, String key) {
    final firestore = _firestore ?? FirebaseBackend.firestore;
    return firestore
        .collection('users')
        .doc(uid)
        .collection(_collection)
        .doc(key);
  }

  @override
  Future<String?> read(String key) async => (await readState(key)).value;

  /// Like [read], telling "no value" apart from "can't tell" ([known] is
  /// false signed in and offline, with nothing cached or copied here).
  Future<({String? value, bool known})> readState(String key) async {
    final uid = _uid;
    if (uid == null) return (value: await _local.read(key), known: true);
    final read = await _readDocumentState(
      uid,
      key,
      fromCopy: (copy) => {'value': copy},
      toCopy: (data) => switch (data['value']) {
        final String value => value,
        _ => null,
      },
    );
    final value = read.data?['value'];
    return (value: value is String ? value : null, known: read.known);
  }

  @override
  Future<void> write(String key, String value) async {
    final uid = _uid;
    if (uid == null) return _local.write(key, value);
    await _writeCopy(uid, key, value);
    await OfflineStore.acceptWrite(_doc(uid, key).set({'value': value}));
  }

  @override
  Future<void> delete(String key) async {
    final uid = _uid;
    if (uid == null) return _local.delete(key);
    await _writeCopy(uid, key, _missing);
    await OfflineStore.acceptWrite(_doc(uid, key).delete());
  }

  @override
  Future<void> deleteAll() async =>
      throw UnsupportedError('Delete named preferences explicitly.');

  @override
  Future<Map<String, String>?> readItems(String key) async =>
      (await readItemsState(key)).items;

  @override
  Future<PreferenceItemsRead> readItemsState(String key) async {
    final uid = _uid;
    if (uid == null) return DevicePreferenceItems(_local).readItemsState(key);
    final read = await _readDocumentState(
      uid,
      key,
      fromCopy: (copy) => {'items': decodePreferenceItems(copy) ?? {}},
      toCopy: (data) => jsonEncode(_itemsOf(data)),
    );
    final data = read.data;
    return (items: data == null ? null : _itemsOf(data), known: read.known);
  }

  String _deferredKey(String uid, String key) => '$uid:$key:deferred';

  @override
  Future<Map<String, String?>?> readDeferred(String key) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final raw = await _local.read(_deferredKey(uid, key));
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return {
        for (final MapEntry(key: item, :value) in decoded.entries)
          if (item is String && (value == null || value is String))
            item: value as String?,
      };
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeDeferred(String key, Map<String, String?>? changes) async {
    final uid = _uid;
    if (uid == null) return;
    final deferredKey = _deferredKey(uid, key);
    if (changes != null) return _local.write(deferredKey, jsonEncode(changes));
    try {
      await _local.delete(deferredKey);
    } catch (_) {
      // Written already: writing the same changes again changes nothing.
    }
  }

  @override
  Future<void> writeItems(String key, Map<String, String?> changes) async {
    final uid = _uid;
    if (uid == null) {
      return DevicePreferenceItems(_local).writeItems(key, changes);
    }
    final items = <String, String?>{
      for (final entry in changes.entries)
        if (entry.key.isNotEmpty) entry.key: entry.value,
    };
    if (items.isEmpty) return;
    final copy = await _readCopy(uid, key);
    final copied = copy == null || copy == _missing
        ? <String, String>{}
        : decodePreferenceItems(copy) ?? {};
    applyPreferenceItemChanges(copied, items);
    await _writeCopy(uid, key, jsonEncode(copied));
    // A merge touches only these items' fields. Never write an empty map
    // here: a merge would replace the whole stored map with it.
    await OfflineStore.acceptWrite(
      _doc(uid, key).set({
        'items': {
          for (final MapEntry(:key, :value) in items.entries)
            key: value ?? FieldValue.delete(),
        },
      }, SetOptions(merge: true)),
    );
  }

  static Map<String, String> _itemsOf(Map<String, dynamic> data) {
    final items = data['items'];
    return items is Map ? _stringItems(items) : {};
  }

  /// The preference document [key]: the SDK cache, then this device's copy,
  /// then (briefly) the server. Tells "doesn't exist" apart from "nobody can
  /// say".
  Future<DocumentRead> _readDocumentState(
    String uid,
    String key, {
    required Map<String, dynamic> Function(String copy) fromCopy,
    required String? Function(Map<String, dynamic> data) toCopy,
  }) async {
    final doc = _doc(uid, key);
    var result = await _sync.readCachedDocument(_collection, doc);
    if (!result.known) {
      final copy = await _readCopy(uid, key);
      if (copy == _missing) return const DocumentRead.missing();
      if (copy != null) return DocumentRead.found(fromCopy(copy));
      result = await _sync.readServerDocument(_collection, doc);
      if (!result.known) return const DocumentRead.unknown();
    }
    final data = result.data;
    final copy = data == null ? null : toCopy(data);
    await _writeCopy(uid, key, copy ?? _missing);
    return result;
  }

  Future<String?> _readCopy(String uid, String key) async {
    try {
      return await _local.read(_copyKey(uid, key));
    } catch (_) {
      return null;
    }
  }

  /// Keeps this device's copy in step; a no-op when it already matches.
  Future<void> _writeCopy(String uid, String key, String copy) async {
    try {
      final copyKey = _copyKey(uid, key);
      if (await _local.read(copyKey) == copy) return;
      await _local.write(copyKey, copy);
    } catch (_) {
      // Best effort: the cache and the server remain the source of truth.
    }
  }
}
