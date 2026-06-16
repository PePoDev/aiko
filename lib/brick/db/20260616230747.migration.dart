// GENERATED CODE EDIT WITH CAUTION
// THIS FILE **WILL NOT** BE REGENERATED
// This file should be version controlled and can be manually edited.
part of 'schema.g.dart';

// While migrations are intelligently created, the difference between some commands, such as
// DropTable vs. RenameTable, cannot be determined. For this reason, please review migrations after
// they are created to ensure the correct inference was made.

// The migration version must **always** mirror the file name

// Profile personal-info expansion: full name, gender, date of birth, phone
// number, and avatar (local cache path + cloud URL). The deleted_at indexes
// the generator also added here are spurious — the model uses hard deletes
// and the `deleted_at` column was dropped in 20260615211634. Removed.

const List<MigrationCommand> _migration_20260616230747_up = [
  InsertColumn('full_name', Column.varchar, onTable: 'OfflineProfile'),
  InsertColumn('gender', Column.varchar, onTable: 'OfflineProfile'),
  InsertColumn('date_of_birth', Column.datetime, onTable: 'OfflineProfile'),
  InsertColumn('phone_number', Column.varchar, onTable: 'OfflineProfile'),
  InsertColumn('avatar_path', Column.varchar, onTable: 'OfflineProfile'),
  InsertColumn('avatar_url', Column.varchar, onTable: 'OfflineProfile'),
];

const List<MigrationCommand> _migration_20260616230747_down = [
  DropColumn('full_name', onTable: 'OfflineProfile'),
  DropColumn('gender', onTable: 'OfflineProfile'),
  DropColumn('date_of_birth', onTable: 'OfflineProfile'),
  DropColumn('phone_number', onTable: 'OfflineProfile'),
  DropColumn('avatar_path', onTable: 'OfflineProfile'),
  DropColumn('avatar_url', onTable: 'OfflineProfile'),
];

//
// DO NOT EDIT BELOW THIS LINE
//

@Migratable(
  version: '20260616230747',
  up: _migration_20260616230747_up,
  down: _migration_20260616230747_down,
)
class Migration20260616230747 extends Migration {
  const Migration20260616230747()
    : super(
        version: 20260616230747,
        up: _migration_20260616230747_up,
        down: _migration_20260616230747_down,
      );
}
