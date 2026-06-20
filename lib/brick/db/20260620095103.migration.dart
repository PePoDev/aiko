// GENERATED CODE EDIT WITH CAUTION
// THIS FILE **WILL NOT** BE REGENERATED
// This file should be version controlled and can be manually edited.
part of 'schema.g.dart';

// While migrations are intelligently created, the difference between some commands, such as
// DropTable vs. RenameTable, cannot be determined. For this reason, please review migrations after
// they are created to ensure the correct inference was made.

// The migration version must **always** mirror the file name

// The generator re-added spurious deleted_at indexes here (see 20260620084032).
// The model uses hard deletes and the `deleted_at` column was dropped in
// 20260615211634, so those indexes target columns that don't exist. Removed,
// keeping only the real onboarding_status drop.
const List<MigrationCommand> _migration_20260620095103_up = [
  DropColumn('onboarding_status', onTable: 'OfflineProfile'),
];

const List<MigrationCommand> _migration_20260620095103_down = [
  InsertColumn('onboarding_status', Column.varchar, onTable: 'OfflineProfile'),
];

//
// DO NOT EDIT BELOW THIS LINE
//

@Migratable(
  version: '20260620095103',
  up: _migration_20260620095103_up,
  down: _migration_20260620095103_down,
)
class Migration20260620095103 extends Migration {
  const Migration20260620095103()
    : super(
        version: 20260620095103,
        up: _migration_20260620095103_up,
        down: _migration_20260620095103_down,
      );
}
