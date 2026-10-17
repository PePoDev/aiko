/// Which records of one collection to read: all fields optional, combined
/// with AND. Field names are row (document) field names, e.g. `date`.
class RecordQuery {
  const RecordQuery({
    this.ownerId,
    this.id,
    this.orderBy,
    this.descending = false,
    this.limit,
  });

  /// Only records of this owner (`user_id`; a profile's own id).
  final String? ownerId;

  /// Only the record with this id.
  final String? id;

  /// Sort by this row field; ascending unless [descending].
  final String? orderBy;
  final bool descending;

  /// At most this many records (after sorting).
  final int? limit;

  /// Sorts [rows] by [orderBy] and applies [limit], as the Firestore query
  /// does. Rows missing the field sort first (Firestore leaves them out;
  /// records written by the app always have the fields callers order by).
  List<Map<String, dynamic>> sortAndLimit(List<Map<String, dynamic>> rows) {
    final field = orderBy;
    var result = rows;
    if (field != null) {
      result = [...rows]
        ..sort((a, b) {
          final order = compareRowValues(a[field], b[field]);
          return descending ? -order : order;
        });
    }
    final max = limit;
    if (max != null && result.length > max) {
      result = result.sublist(0, max);
    }
    return result;
  }
}

/// Orders row values by type first (null, bool, number, string, other), then
/// by value, following Firestore's ordering of mixed types.
int compareRowValues(Object? a, Object? b) {
  final byType = _typeRank(a).compareTo(_typeRank(b));
  if (byType != 0) return byType;
  return switch ((a, b)) {
    (final bool x, final bool y) => x == y ? 0 : (x ? 1 : -1),
    (final num x, final num y) => x.compareTo(y),
    (final String x, final String y) => x.compareTo(y),
    _ => 0,
  };
}

int _typeRank(Object? value) => switch (value) {
  null => 0,
  bool() => 1,
  num() => 2,
  String() => 3,
  _ => 4,
};
