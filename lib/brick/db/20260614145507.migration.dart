// GENERATED CODE EDIT WITH CAUTION
// THIS FILE **WILL NOT** BE REGENERATED
// This file should be version controlled and can be manually edited.
part of 'schema.g.dart';

// While migrations are intelligently created, the difference between some commands, such as
// DropTable vs. RenameTable, cannot be determined. For this reason, please review migrations after
// they are created to ensure the correct inference was made.

// The migration version must **always** mirror the file name

const List<MigrationCommand> _migration_20260614145507_up = [
  InsertColumn('details_json', Column.varchar, onTable: 'OfflineAccount')
];

const List<MigrationCommand> _migration_20260614145507_down = [
  DropColumn('details_json', onTable: 'OfflineAccount')
];

//
// DO NOT EDIT BELOW THIS LINE
//

@Migratable(
  version: '20260614145507',
  up: _migration_20260614145507_up,
  down: _migration_20260614145507_down,
)
class Migration20260614145507 extends Migration {
  const Migration20260614145507()
    : super(
        version: 20260614145507,
        up: _migration_20260614145507_up,
        down: _migration_20260614145507_down,
      );
}
