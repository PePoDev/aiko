// GENERATED CODE EDIT WITH CAUTION
// THIS FILE **WILL NOT** BE REGENERATED
// This file should be version controlled and can be manually edited.
part of 'schema.g.dart';

// Budgets -> Categories merge: per-category budget fields added to
// OfflineCategory. Goals -> Accounts merge: goal fields added to OfflineAccount.
// The legacy `budgets` and `goals` tables (added by earlier migrations) are
// not touched here — the one-time data migration in
// `lib/core/sync/budget_goal_migration.dart` reads them and drops them.

const List<MigrationCommand> _migration_20260615000000_up = [
  InsertColumn('budget_amount', Column.varchar, onTable: 'OfflineCategory'),
  InsertColumn('budget_currency', Column.varchar, onTable: 'OfflineCategory'),
  InsertColumn('budget_period', Column.varchar, onTable: 'OfflineCategory'),
  InsertColumn('budget_rollover', Column.boolean, onTable: 'OfflineCategory'),
  InsertColumn('alert_thresholds', Column.varchar, onTable: 'OfflineCategory'),
  InsertColumn('goal_target_amount', Column.varchar, onTable: 'OfflineAccount'),
  InsertColumn('goal_target_date', Column.varchar, onTable: 'OfflineAccount'),
  InsertColumn('goal_priority', Column.varchar, onTable: 'OfflineAccount'),
];

const List<MigrationCommand> _migration_20260615000000_down = [
  DropColumn('alert_thresholds', onTable: 'OfflineCategory'),
  DropColumn('budget_rollover', onTable: 'OfflineCategory'),
  DropColumn('budget_period', onTable: 'OfflineCategory'),
  DropColumn('budget_currency', onTable: 'OfflineCategory'),
  DropColumn('budget_amount', onTable: 'OfflineCategory'),
  DropColumn('goal_priority', onTable: 'OfflineAccount'),
  DropColumn('goal_target_date', onTable: 'OfflineAccount'),
  DropColumn('goal_target_amount', onTable: 'OfflineAccount'),
];

//
// DO NOT EDIT BELOW THIS LINE
//

@Migratable(
  version: '20260615000000',
  up: _migration_20260615000000_up,
  down: _migration_20260615000000_down,
)
class Migration20260615000000 extends Migration {
  const Migration20260615000000()
    : super(
        version: 20260615000000,
        up: _migration_20260615000000_up,
        down: _migration_20260615000000_down,
      );
}
