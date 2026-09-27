import 'package:brick_core/core.dart';
import 'package:brick_sqlite/brick_sqlite.dart';

/// One codec for Firebase documents and the existing local SQLite schema.
abstract class FirestoreAdapter<T extends SqliteModel>
    extends SqliteAdapter<T> {
  String get collectionName;
  Future<T> fromFirestore(
    Map<String, dynamic> input, {
    Object? provider,
    ModelRepository<SqliteModel>? repository,
  });
  Future<Map<String, dynamic>> toFirestore(
    T input, {
    Object? provider,
    ModelRepository<SqliteModel>? repository,
  });
}
