// GENERATED CODE EDIT WITH CAUTION
// THIS FILE **WILL NOT** BE REGENERATED
// This file should be version controlled and can be manually edited.
part of 'schema.g.dart';

// While migrations are intelligently created, the difference between some commands, such as
// DropTable vs. RenameTable, cannot be determined. For this reason, please review migrations after
// they are created to ensure the correct inference was made.

// The migration version must **always** mirror the file name

// The generator re-added spurious deleted_at indexes here (see 20260617195026).
// The model uses hard deletes and the `deleted_at` column was dropped in
// 20260615211634, so those indexes target columns that don't exist. Removed,
// keeping only the real reminder_at column.

const List<MigrationCommand> _migration_20260620084032_up = [
  InsertColumn('reminder_at', Column.datetime, onTable: 'OfflineTransaction'),
];

const List<MigrationCommand> _migration_20260620084032_down = [
  DropColumn('reminder_at', onTable: 'OfflineTransaction'),
];

//
// DO NOT EDIT BELOW THIS LINE
//

@Migratable(
  version: '20260620084032',
  up: _migration_20260620084032_up,
  down: _migration_20260620084032_down,
)
class Migration20260620084032 extends Migration {
  const Migration20260620084032()
    : super(
        version: 20260620084032,
        up: _migration_20260620084032_up,
        down: _migration_20260620084032_down,
      );
}
