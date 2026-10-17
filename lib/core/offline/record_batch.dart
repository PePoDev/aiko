import 'records/record_codec.dart';

/// One write of a [RecordBatch]: put [row] at [collection]/[id], or delete
/// that record when [row] is null.
class RecordWrite {
  const RecordWrite.put({
    required this.collection,
    required this.id,
    required this.ownerId,
    required Map<String, dynamic> this.row,
  });

  const RecordWrite.delete({
    required this.collection,
    required this.id,
    this.ownerId,
  }) : row = null;

  final String collection;
  final String id;

  /// The record's owner. For a delete, null means "whoever owns it"; given,
  /// only that owner's record is deleted.
  final String? ownerId;

  /// The full document row to store; null for a delete.
  final Map<String, dynamic>? row;

  bool get isDelete => row == null;

  @override
  String toString() =>
      'RecordWrite(${isDelete ? 'delete' : 'put'} $collection/$id)';
}

/// Writes that are applied together or not at all: one Firestore WriteBatch
/// when signed in, one SQLite transaction otherwise (`OfflineStore.commit`).
///
/// Writes apply in the order they are added. Repositories stage into a batch
/// when one is passed to their `save` / `delete`.
class RecordBatch {
  final List<RecordWrite> _writes = [];

  List<RecordWrite> get writes => List.unmodifiable(_writes);
  int get length => _writes.length;
  bool get isEmpty => _writes.isEmpty;
  bool get isNotEmpty => _writes.isNotEmpty;

  /// Stores [record] (insert or replace).
  void upsert(OfflineRecord record) {
    final codec = RecordCodecs.forRecord(record);
    _writes.add(
      RecordWrite.put(
        collection: codec.collection,
        id: codec.idOf(record),
        ownerId: codec.ownerOf(record),
        row: codec.toRow(record),
      ),
    );
  }

  /// Deletes [record].
  void delete(OfflineRecord record) {
    final codec = RecordCodecs.forRecord(record);
    _writes.add(
      RecordWrite.delete(
        collection: codec.collection,
        id: codec.idOf(record),
        ownerId: codec.ownerOf(record),
      ),
    );
  }

  /// Deletes the [T] record with [id] (of [ownerId] when given) without
  /// reading it first.
  void deleteById<T extends OfflineRecord>(String id, {String? ownerId}) {
    _writes.add(
      RecordWrite.delete(
        collection: RecordCodecs.of<T>().collection,
        id: id,
        ownerId: ownerId,
      ),
    );
  }

  /// Adds an already built write.
  void add(RecordWrite write) => _writes.add(write);
}
