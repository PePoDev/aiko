// GENERATED CODE EDIT WITH CAUTION
// THIS FILE **WILL NOT** BE REGENERATED
// This file should be version controlled and can be manually edited.
part of 'schema.g.dart';

// Drop the legacy `OfflineBudget` and `OfflineGoal` tables now that the new
// category/account shape is the only one the app reads.

const List<MigrationCommand> _migration_20260615060000_up = [
  DropTable('OfflineBudget'),
  DropTable('OfflineGoal'),
];

const List<MigrationCommand> _migration_20260615060000_down = [
  // Down-migration recreates the legacy tables empty. A real restore from a
  // pre-merge backup is the supported recovery path.
];

//
// DO NOT EDIT BELOW THIS LINE
//

@Migratable(
  version: '20260615060000',
  up: _migration_20260615060000_up,
  down: _migration_20260615060000_down,
)
class Migration20260615060000 extends Migration {
  const Migration20260615060000()
    : super(
        version: 20260615060000,
        up: _migration_20260615060000_up,
        down: _migration_20260615060000_down,
      );
}
