// GENERATED CODE EDIT WITH CAUTION
// THIS FILE **WILL NOT** BE REGENERATED
// This file should be version controlled and can be manually edited.
part of 'schema.g.dart';

// While migrations are intelligently created, the difference between some commands, such as
// DropTable vs. RenameTable, cannot be determined. For this reason, please review migrations after
// they are created to ensure the correct inference was made.

// The migration version must **always** mirror the file name

const List<MigrationCommand> _migration_20260620084032_up = [
  InsertColumn('reminder_at', Column.datetime, onTable: 'OfflineTransaction'),
  CreateIndex(columns: ['deleted_at'], onTable: 'OfflineAccount', unique: false),
  CreateIndex(columns: ['deleted_at'], onTable: 'OfflineCategory', unique: false),
  CreateIndex(columns: ['deleted_at'], onTable: 'OfflineProfile', unique: false),
  CreateIndex(columns: ['deleted_at'], onTable: 'OfflineTransaction', unique: false),
  CreateIndex(columns: ['deleted_at'], onTable: 'OfflineInvestmentHolding', unique: false),
  CreateIndex(columns: ['deleted_at'], onTable: 'OfflineCategoryGroup', unique: false)
];

const List<MigrationCommand> _migration_20260620084032_down = [
  DropColumn('reminder_at', onTable: 'OfflineTransaction'),
  DropIndex('index_OfflineAccount_on_deleted_at'),
  DropIndex('index_OfflineCategory_on_deleted_at'),
  DropIndex('index_OfflineProfile_on_deleted_at'),
  DropIndex('index_OfflineTransaction_on_deleted_at'),
  DropIndex('index_OfflineInvestmentHolding_on_deleted_at'),
  DropIndex('index_OfflineCategoryGroup_on_deleted_at')
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
