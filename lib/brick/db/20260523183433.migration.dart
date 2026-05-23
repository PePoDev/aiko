// GENERATED CODE EDIT WITH CAUTION
// THIS FILE **WILL NOT** BE REGENERATED
// This file should be version controlled and can be manually edited.
part of 'schema.g.dart';

// While migrations are intelligently created, the difference between some commands, such as
// DropTable vs. RenameTable, cannot be determined. For this reason, please review migrations after
// they are created to ensure the correct inference was made.

// The migration version must **always** mirror the file name

const List<MigrationCommand> _migration_20260523183433_up = [
  InsertColumn(
    'included_category_ids',
    Column.varchar,
    onTable: 'OfflineBudget',
  ),
  InsertColumn('is_app_defined', Column.boolean, onTable: 'OfflineBudget'),
];

const List<MigrationCommand> _migration_20260523183433_down = [
  DropColumn('included_category_ids', onTable: 'OfflineBudget'),
  DropColumn('is_app_defined', onTable: 'OfflineBudget'),
];

//
// DO NOT EDIT BELOW THIS LINE
//

@Migratable(
  version: '20260523183433',
  up: _migration_20260523183433_up,
  down: _migration_20260523183433_down,
)
class Migration20260523183433 extends Migration {
  const Migration20260523183433()
    : super(
        version: 20260523183433,
        up: _migration_20260523183433_up,
        down: _migration_20260523183433_down,
      );
}
