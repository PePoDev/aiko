// These fakes stand in for the SDK on an offline device.
// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// A Firestore on an offline device: the server never answers, writes are
/// never acknowledged, and the cache holds only what was written here (a
/// document it never saw fails to read from the cache, as in the SDK).
class OfflineFirestore extends Fake implements FirebaseFirestore {
  final _cache = <String, Map<String, dynamic>?>{};

  /// How many reads tried the server.
  var serverReads = 0;

  /// Empties the cache, as after a reinstall that kept the session.
  void forgetCache() => _cache.clear();

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _OfflineCollection(this, path);
}

class _OfflineCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _OfflineCollection(this._db, this._path);

  final OfflineFirestore _db;
  final String _path;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? id]) =>
      _OfflineDoc(_db, '$_path/$id');
}

class _OfflineDoc extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _OfflineDoc(this._db, this._path);

  final OfflineFirestore _db;
  final String _path;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _OfflineCollection(_db, '$_path/$path');

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) {
    if (options?.source == Source.cache) {
      if (!_db._cache.containsKey(_path)) {
        return Future.error(
          FirebaseException(plugin: 'test', code: 'unavailable'),
        );
      }
      return Future.value(_Snapshot(_db._cache[_path]));
    }
    _db.serverReads++;
    return Completer<DocumentSnapshot<Map<String, dynamic>>>().future;
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) {
    final current = options?.merge == true
        ? {...?_db._cache[_path]}
        : <String, dynamic>{};
    for (final MapEntry(:key, :value) in data.entries) {
      if (value is Map) {
        final previous = current[key];
        final merged = <String, dynamic>{
          if (options?.merge == true && previous is Map)
            ...previous.cast<String, dynamic>(),
        };
        for (final MapEntry(key: item, value: itemValue) in value.entries) {
          // Only FieldValue.delete() is used with maps here.
          if (itemValue is FieldValue) {
            merged.remove(item);
          } else {
            merged[item as String] = itemValue;
          }
        }
        current[key] = merged;
      } else {
        current[key] = value;
      }
    }
    _db._cache[_path] = current;
    return Completer<void>().future;
  }

  @override
  Future<void> delete() {
    _db._cache[_path] = null;
    return Completer<void>().future;
  }
}

class _Snapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this._data);

  final Map<String, dynamic>? _data;

  @override
  bool get exists => _data != null;

  @override
  Map<String, dynamic>? data() => _data;
}
