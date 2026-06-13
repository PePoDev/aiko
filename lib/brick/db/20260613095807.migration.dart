// GENERATED CODE EDIT WITH CAUTION
// THIS FILE **WILL NOT** BE REGENERATED
// This file should be version controlled and can be manually edited.
part of 'schema.g.dart';

// While migrations are intelligently created, the difference between some commands, such as
// DropTable vs. RenameTable, cannot be determined. For this reason, please review migrations after
// they are created to ensure the correct inference was made.

// The migration version must **always** mirror the file name

const List<MigrationCommand> _migration_20260613095807_up = [
  InsertTable('OfflineInvestmentHolding'),
  InsertColumn('id', Column.varchar, onTable: 'OfflineInvestmentHolding', unique: true),
  InsertColumn('user_id', Column.varchar, onTable: 'OfflineInvestmentHolding'),
  InsertColumn('symbol', Column.varchar, onTable: 'OfflineInvestmentHolding'),
  InsertColumn('asset_class', Column.varchar, onTable: 'OfflineInvestmentHolding'),
  InsertColumn('quantity', Column.varchar, onTable: 'OfflineInvestmentHolding'),
  InsertColumn('average_cost', Column.varchar, onTable: 'OfflineInvestmentHolding'),
  InsertColumn('current_price', Column.varchar, onTable: 'OfflineInvestmentHolding'),
  InsertColumn('currency', Column.varchar, onTable: 'OfflineInvestmentHolding'),
  InsertColumn('market_value', Column.varchar, onTable: 'OfflineInvestmentHolding'),
  InsertColumn('target_allocation_percent', Column.Double, onTable: 'OfflineInvestmentHolding'),
  InsertColumn('created_at', Column.datetime, onTable: 'OfflineInvestmentHolding'),
  InsertColumn('updated_at', Column.datetime, onTable: 'OfflineInvestmentHolding'),
  CreateIndex(columns: ['user_id'], onTable: 'OfflineInvestmentHolding', unique: false)
];

const List<MigrationCommand> _migration_20260613095807_down = [
  DropTable('OfflineInvestmentHolding'),
  DropColumn('id', onTable: 'OfflineInvestmentHolding'),
  DropColumn('user_id', onTable: 'OfflineInvestmentHolding'),
  DropColumn('symbol', onTable: 'OfflineInvestmentHolding'),
  DropColumn('asset_class', onTable: 'OfflineInvestmentHolding'),
  DropColumn('quantity', onTable: 'OfflineInvestmentHolding'),
  DropColumn('average_cost', onTable: 'OfflineInvestmentHolding'),
  DropColumn('current_price', onTable: 'OfflineInvestmentHolding'),
  DropColumn('currency', onTable: 'OfflineInvestmentHolding'),
  DropColumn('market_value', onTable: 'OfflineInvestmentHolding'),
  DropColumn('target_allocation_percent', onTable: 'OfflineInvestmentHolding'),
  DropColumn('created_at', onTable: 'OfflineInvestmentHolding'),
  DropColumn('updated_at', onTable: 'OfflineInvestmentHolding'),
  DropIndex('index_OfflineInvestmentHolding_on_user_id')
];

//
// DO NOT EDIT BELOW THIS LINE
//

@Migratable(
  version: '20260613095807',
  up: _migration_20260613095807_up,
  down: _migration_20260613095807_down,
)
class Migration20260613095807 extends Migration {
  const Migration20260613095807()
    : super(
        version: 20260613095807,
        up: _migration_20260613095807_up,
        down: _migration_20260613095807_down,
      );
}
