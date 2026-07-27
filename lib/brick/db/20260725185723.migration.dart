// GENERATED CODE EDIT WITH CAUTION
// THIS FILE **WILL NOT** BE REGENERATED
// This file should be version controlled and can be manually edited.
part of 'schema.g.dart';

// While migrations are intelligently created, the difference between some commands, such as
// DropTable vs. RenameTable, cannot be determined. For this reason, please review migrations after
// they are created to ensure the correct inference was made.

// The migration version must **always** mirror the file name

const List<MigrationCommand> _migration_20260725185723_up = [
  InsertColumn('template_id', Column.varchar, onTable: 'OfflineCategory'),
  InsertColumn('template_id', Column.varchar, onTable: 'OfflineCategoryGroup'),
  // Brick re-generated deleted_at indexes even though those columns were
  // removed in migration 20260615211634. Keep this migration to template_id.
];

const List<MigrationCommand> _migration_20260725185723_down = [
  DropColumn('template_id', onTable: 'OfflineCategory'),
  DropColumn('template_id', onTable: 'OfflineCategoryGroup'),
];

//
// DO NOT EDIT BELOW THIS LINE
//

@Migratable(
  version: '20260725185723',
  up: _migration_20260725185723_up,
  down: _migration_20260725185723_down,
)
class Migration20260725185723 extends Migration {
  const Migration20260725185723()
    : super(
        version: 20260725185723,
        up: _migration_20260725185723_up,
        down: _migration_20260725185723_down,
      );
}
