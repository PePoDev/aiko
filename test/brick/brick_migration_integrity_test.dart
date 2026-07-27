import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('latest Brick migration does not index removed deleted_at columns', () {
    final source = File(
      'lib/brick/db/20260725185723.migration.dart',
    ).readAsStringSync();

    expect(source, contains("InsertColumn('template_id'"));
    expect(
      source,
      isNot(contains("columns: ['deleted_at']")),
      reason: 'deleted_at was removed by migration 20260615211634',
    );
    expect(
      source,
      isNot(contains('_on_deleted_at')),
      reason: 'down migrations must not drop indexes that no longer exist',
    );
  });

  test('generated schema version matches the latest migration', () {
    final source = File('lib/brick/db/schema.g.dart').readAsStringSync();

    expect(source, contains('final schema = Schema(\n  20260725185723,'));
  });
}
