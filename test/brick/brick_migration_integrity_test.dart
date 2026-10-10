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

  test('transfer link migration adds transfer_group_id to transactions', () {
    final source = File(
      'lib/brick/db/20261010120000.migration.dart',
    ).readAsStringSync();

    expect(source, contains('InsertColumn('));
    expect(source, contains("'transfer_group_id'"));
    expect(source, contains("onTable: 'OfflineTransaction'"));
  });

  test('generated schema version matches the latest migration', () {
    final source = File('lib/brick/db/schema.g.dart').readAsStringSync();

    expect(source, contains('final schema = Schema(\n  20261010120000,'));
    expect(source, contains('const Migration20261010120000(),'));
  });
}
