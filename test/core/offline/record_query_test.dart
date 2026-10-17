import 'package:aiko/core/offline/record_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final rows = [
    {'id': 'b', 'name': 'Bank'},
    {'id': 'none'},
    {'id': 'a', 'name': 'Allowance'},
    {'id': 'c', 'name': 'cash'},
  ];

  test('sorts by a field, missing values first', () {
    final sorted = const RecordQuery(orderBy: 'name').sortAndLimit(rows);
    expect(sorted.map((row) => row['id']), ['none', 'a', 'b', 'c']);
  });

  test('descending and limit', () {
    final sorted = const RecordQuery(
      orderBy: 'name',
      descending: true,
      limit: 2,
    ).sortAndLimit(rows);
    expect(sorted.map((row) => row['id']), ['c', 'b']);
  });

  test('without an order only the limit applies', () {
    expect(const RecordQuery(limit: 1).sortAndLimit(rows), [rows.first]);
    expect(const RecordQuery().sortAndLimit(rows), rows);
  });

  test('mixed types order by type, then value', () {
    expect(compareRowValues(null, false), lessThan(0));
    expect(compareRowValues(true, 1), lessThan(0));
    expect(compareRowValues(2, 10.5), lessThan(0));
    expect(compareRowValues(99, 'a'), lessThan(0));
    expect(compareRowValues('b', 'a'), greaterThan(0));
    expect(compareRowValues('2026-05-01', '2026-10-01'), lessThan(0));
  });
}
