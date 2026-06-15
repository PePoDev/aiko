// GENERATED CODE EDIT WITH CAUTION
// THIS FILE **WILL NOT** BE REGENERATED
// This file should be version controlled and can be manually edited.
part of 'schema.g.dart';

// While migrations are intelligently created, the difference between some commands, such as
// DropTable vs. RenameTable, cannot be determined. For this reason, please review migrations after
// they are created to ensure the correct inference was made.

// The migration version must **always** mirror the file name

const List<MigrationCommand> _migration_20260615211634_up = [
  DropIndex('index_OfflineAccount_on_deleted_at'),
  DropIndex('index_OfflineCategory_on_deleted_at'),
  DropIndex('index_OfflineProfile_on_deleted_at'),
  DropIndex('index_OfflineTransaction_on_deleted_at'),
  DropIndex('index_OfflineInvestmentHolding_on_deleted_at'),
  DropIndex('index_OfflineCategoryGroup_on_deleted_at'),
  DropColumn('deleted_at', onTable: 'OfflineAccount'),
  DropColumn('deleted_at', onTable: 'OfflineCategory'),
  DropColumn('deleted_at', onTable: 'OfflineProfile'),
  DropColumn('deleted_at', onTable: 'OfflineTransaction'),
  DropColumn('deleted_at', onTable: 'OfflineInvestmentHolding'),
  DropColumn('deleted_at', onTable: 'OfflineCategoryGroup'),
];

const List<MigrationCommand> _migration_20260615211634_down = [
  InsertColumn('deleted_at', Column.datetime, onTable: 'OfflineAccount'),
  InsertColumn('deleted_at', Column.datetime, onTable: 'OfflineCategory'),
  InsertColumn('deleted_at', Column.datetime, onTable: 'OfflineProfile'),
  InsertColumn('deleted_at', Column.datetime, onTable: 'OfflineTransaction'),
  InsertColumn(
    'deleted_at',
    Column.datetime,
    onTable: 'OfflineInvestmentHolding',
  ),
  InsertColumn('deleted_at', Column.datetime, onTable: 'OfflineCategoryGroup'),
  CreateIndex(
    columns: ['deleted_at'],
    onTable: 'OfflineAccount',
    unique: false,
  ),
  CreateIndex(
    columns: ['deleted_at'],
    onTable: 'OfflineCategory',
    unique: false,
  ),
  CreateIndex(
    columns: ['deleted_at'],
    onTable: 'OfflineProfile',
    unique: false,
  ),
  CreateIndex(
    columns: ['deleted_at'],
    onTable: 'OfflineTransaction',
    unique: false,
  ),
  CreateIndex(
    columns: ['deleted_at'],
    onTable: 'OfflineInvestmentHolding',
    unique: false,
  ),
  CreateIndex(
    columns: ['deleted_at'],
    onTable: 'OfflineCategoryGroup',
    unique: false,
  ),
];

//
// DO NOT EDIT BELOW THIS LINE
//

@Migratable(
  version: '20260615211634',
  up: _migration_20260615211634_up,
  down: _migration_20260615211634_down,
)
class Migration20260615211634 extends Migration {
  const Migration20260615211634()
    : super(
        version: 20260615211634,
        up: _migration_20260615211634_up,
        down: _migration_20260615211634_down,
      );
}
