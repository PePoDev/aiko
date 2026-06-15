// GENERATED CODE EDIT WITH CAUTION
// THIS FILE **WILL NOT** BE REGENERATED
// This file should be version controlled and can be manually edited.
part of 'schema.g.dart';

// While migrations are intelligently created, the difference between some commands, such as
// DropTable vs. RenameTable, cannot be determined. For this reason, please review migrations after
// they are created to ensure the correct inference was made.

// The migration version must **always** mirror the file name

const List<MigrationCommand> _migration_20260615204827_up = [
  DropColumn('goal_target_date', onTable: 'OfflineAccount'),
  InsertColumn('goal_target_date', Column.datetime, onTable: 'OfflineAccount'),
  InsertColumn('updated_at', Column.datetime, onTable: 'OfflineAccount'),
  InsertColumn('deleted_at', Column.datetime, onTable: 'OfflineAccount'),
  InsertColumn('version', Column.integer, onTable: 'OfflineAccount'),
  InsertColumn('updated_at', Column.datetime, onTable: 'OfflineCategory'),
  InsertColumn('deleted_at', Column.datetime, onTable: 'OfflineCategory'),
  InsertColumn('version', Column.integer, onTable: 'OfflineCategory'),
  InsertColumn('updated_at', Column.datetime, onTable: 'OfflineCategoryGroup'),
  InsertColumn('deleted_at', Column.datetime, onTable: 'OfflineCategoryGroup'),
  InsertColumn('version', Column.integer, onTable: 'OfflineCategoryGroup'),
  InsertColumn('deleted_at', Column.datetime, onTable: 'OfflineInvestmentHolding'),
  InsertColumn('version', Column.integer, onTable: 'OfflineInvestmentHolding'),
  InsertColumn('updated_at', Column.datetime, onTable: 'OfflineProfile'),
  InsertColumn('deleted_at', Column.datetime, onTable: 'OfflineProfile'),
  InsertColumn('version', Column.integer, onTable: 'OfflineProfile'),
  InsertColumn('updated_at', Column.datetime, onTable: 'OfflineTransaction'),
  InsertColumn('deleted_at', Column.datetime, onTable: 'OfflineTransaction'),
  InsertColumn('version', Column.integer, onTable: 'OfflineTransaction'),
  CreateIndex(columns: ['deleted_at'], onTable: 'OfflineAccount', unique: false),
  CreateIndex(columns: ['deleted_at'], onTable: 'OfflineCategory', unique: false),
  CreateIndex(columns: ['deleted_at'], onTable: 'OfflineCategoryGroup', unique: false),
  CreateIndex(columns: ['deleted_at'], onTable: 'OfflineInvestmentHolding', unique: false),
  CreateIndex(columns: ['deleted_at'], onTable: 'OfflineProfile', unique: false),
  CreateIndex(columns: ['deleted_at'], onTable: 'OfflineTransaction', unique: false)
];

const List<MigrationCommand> _migration_20260615204827_down = [
  DropColumn('goal_target_date', onTable: 'OfflineAccount'),
  DropColumn('updated_at', onTable: 'OfflineAccount'),
  DropColumn('deleted_at', onTable: 'OfflineAccount'),
  DropColumn('version', onTable: 'OfflineAccount'),
  DropColumn('updated_at', onTable: 'OfflineCategory'),
  DropColumn('deleted_at', onTable: 'OfflineCategory'),
  DropColumn('version', onTable: 'OfflineCategory'),
  DropColumn('updated_at', onTable: 'OfflineCategoryGroup'),
  DropColumn('deleted_at', onTable: 'OfflineCategoryGroup'),
  DropColumn('version', onTable: 'OfflineCategoryGroup'),
  DropColumn('deleted_at', onTable: 'OfflineInvestmentHolding'),
  DropColumn('version', onTable: 'OfflineInvestmentHolding'),
  DropColumn('updated_at', onTable: 'OfflineProfile'),
  DropColumn('deleted_at', onTable: 'OfflineProfile'),
  DropColumn('version', onTable: 'OfflineProfile'),
  DropColumn('updated_at', onTable: 'OfflineTransaction'),
  DropColumn('deleted_at', onTable: 'OfflineTransaction'),
  DropColumn('version', onTable: 'OfflineTransaction'),
  DropIndex('index_OfflineAccount_on_deleted_at'),
  DropIndex('index_OfflineCategory_on_deleted_at'),
  DropIndex('index_OfflineCategoryGroup_on_deleted_at'),
  DropIndex('index_OfflineInvestmentHolding_on_deleted_at'),
  DropIndex('index_OfflineProfile_on_deleted_at'),
  DropIndex('index_OfflineTransaction_on_deleted_at')
];

//
// DO NOT EDIT BELOW THIS LINE
//

@Migratable(
  version: '20260615204827',
  up: _migration_20260615204827_up,
  down: _migration_20260615204827_down,
)
class Migration20260615204827 extends Migration {
  const Migration20260615204827()
    : super(
        version: 20260615204827,
        up: _migration_20260615204827_up,
        down: _migration_20260615204827_down,
      );
}
