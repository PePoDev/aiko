// GENERATED CODE EDIT WITH CAUTION
// THIS FILE **WILL NOT** BE REGENERATED
// This file should be version controlled and can be manually edited.
part of 'schema.g.dart';

// While migrations are intelligently created, the difference between some commands, such as
// DropTable vs. RenameTable, cannot be determined. For this reason, please review migrations after
// they are created to ensure the correct inference was made.

// The migration version must **always** mirror the file name

const List<MigrationCommand> _migration_20260613154239_up = [
  InsertTable('OfflineCategoryGroup'),
  InsertColumn('group_id', Column.varchar, onTable: 'OfflineCategory'),
  InsertColumn(
    'id',
    Column.varchar,
    onTable: 'OfflineCategoryGroup',
    unique: true,
  ),
  InsertColumn('user_id', Column.varchar, onTable: 'OfflineCategoryGroup'),
  InsertColumn('name', Column.varchar, onTable: 'OfflineCategoryGroup'),
  InsertColumn('icon', Column.varchar, onTable: 'OfflineCategoryGroup'),
  InsertColumn('color', Column.varchar, onTable: 'OfflineCategoryGroup'),
  InsertColumn('sort_order', Column.integer, onTable: 'OfflineCategoryGroup'),
  InsertColumn('created_at', Column.datetime, onTable: 'OfflineCategoryGroup'),
  CreateIndex(
    columns: ['user_id'],
    onTable: 'OfflineCategoryGroup',
    unique: false,
  ),
];

const List<MigrationCommand> _migration_20260613154239_down = [
  DropTable('OfflineCategoryGroup'),
  DropColumn('group_id', onTable: 'OfflineCategory'),
  DropColumn('id', onTable: 'OfflineCategoryGroup'),
  DropColumn('user_id', onTable: 'OfflineCategoryGroup'),
  DropColumn('name', onTable: 'OfflineCategoryGroup'),
  DropColumn('icon', onTable: 'OfflineCategoryGroup'),
  DropColumn('color', onTable: 'OfflineCategoryGroup'),
  DropColumn('sort_order', onTable: 'OfflineCategoryGroup'),
  DropColumn('created_at', onTable: 'OfflineCategoryGroup'),
  DropIndex('index_OfflineCategoryGroup_on_user_id'),
];

//
// DO NOT EDIT BELOW THIS LINE
//

@Migratable(
  version: '20260613154239',
  up: _migration_20260613154239_up,
  down: _migration_20260613154239_down,
)
class Migration20260613154239 extends Migration {
  const Migration20260613154239()
    : super(
        version: 20260613154239,
        up: _migration_20260613154239_up,
        down: _migration_20260613154239_down,
      );
}
