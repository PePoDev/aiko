// GENERATED CODE EDIT WITH CAUTION
// THIS FILE **WILL NOT** BE REGENERATED
// This file should be version controlled and can be manually edited.
part of 'schema.g.dart';

// While migrations are intelligently created, the difference between some commands, such as
// DropTable vs. RenameTable, cannot be determined. For this reason, please review migrations after
// they are created to ensure the correct inference was made.

// The migration version must **always** mirror the file name

// The generator re-added spurious deleted_at indexes here. The model uses
// hard deletes and the `deleted_at` column was dropped in 20260615211634, so
// these indexes target columns that don't exist. Emptied (see 20260616230747).

const List<MigrationCommand> _migration_20260617195026_up = [];

const List<MigrationCommand> _migration_20260617195026_down = [];

//
// DO NOT EDIT BELOW THIS LINE
//

@Migratable(
  version: '20260617195026',
  up: _migration_20260617195026_up,
  down: _migration_20260617195026_down,
)
class Migration20260617195026 extends Migration {
  const Migration20260617195026()
    : super(
        version: 20260617195026,
        up: _migration_20260617195026_up,
        down: _migration_20260617195026_down,
      );
}
