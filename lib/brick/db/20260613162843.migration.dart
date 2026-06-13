// GENERATED CODE EDIT WITH CAUTION
// THIS FILE **WILL NOT** BE REGENERATED
// This file should be version controlled and can be manually edited.
part of 'schema.g.dart';

// While migrations are intelligently created, the difference between some commands, such as
// DropTable vs. RenameTable, cannot be determined. For this reason, please review migrations after
// they are created to ensure the correct inference was made.

// The migration version must **always** mirror the file name

const List<MigrationCommand> _migration_20260613162843_up = [
  InsertColumn('is_recurring', Column.boolean, onTable: 'OfflineTransaction'),
  InsertColumn('recurring_frequency', Column.varchar, onTable: 'OfflineTransaction'),
  InsertColumn('recurring_end_date', Column.datetime, onTable: 'OfflineTransaction'),
  InsertColumn('recurring_max_occurrences', Column.integer, onTable: 'OfflineTransaction'),
  InsertColumn('recurring_day_of_week', Column.integer, onTable: 'OfflineTransaction'),
  InsertColumn('recurring_day_of_month', Column.integer, onTable: 'OfflineTransaction'),
  InsertColumn('recurring_month_of_year', Column.integer, onTable: 'OfflineTransaction')
];

const List<MigrationCommand> _migration_20260613162843_down = [
  DropColumn('is_recurring', onTable: 'OfflineTransaction'),
  DropColumn('recurring_frequency', onTable: 'OfflineTransaction'),
  DropColumn('recurring_end_date', onTable: 'OfflineTransaction'),
  DropColumn('recurring_max_occurrences', onTable: 'OfflineTransaction'),
  DropColumn('recurring_day_of_week', onTable: 'OfflineTransaction'),
  DropColumn('recurring_day_of_month', onTable: 'OfflineTransaction'),
  DropColumn('recurring_month_of_year', onTable: 'OfflineTransaction')
];

//
// DO NOT EDIT BELOW THIS LINE
//

@Migratable(
  version: '20260613162843',
  up: _migration_20260613162843_up,
  down: _migration_20260613162843_down,
)
class Migration20260613162843 extends Migration {
  const Migration20260613162843()
    : super(
        version: 20260613162843,
        up: _migration_20260613162843_up,
        down: _migration_20260613162843_down,
      );
}
