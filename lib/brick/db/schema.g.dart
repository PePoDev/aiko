// GENERATED CODE DO NOT EDIT
// This file should be version controlled
import 'package:brick_sqlite/db.dart';
part '20260725185723.migration.dart';
part '20260523055312.migration.dart';
part '20260523183433.migration.dart';
part '20260603133701.migration.dart';
part '20260607174822.migration.dart';
part '20260613095807.migration.dart';
part '20260613154239.migration.dart';
part '20260613162843.migration.dart';
part '20260614125205.migration.dart';
part '20260614145507.migration.dart';
part '20260615000000.migration.dart';
part '20260615060000.migration.dart';
part '20260615204827.migration.dart';
part '20260615211634.migration.dart';
part '20260616180151.migration.dart';
part '20260616230747.migration.dart';
part '20260617195026.migration.dart';
part '20260620084032.migration.dart';
part '20260620095103.migration.dart';

/// All intelligently-generated migrations from all `@Migratable` classes on disk
final migrations = <Migration>{
  const Migration20260725185723(),
  const Migration20260523055312(),
  const Migration20260523183433(),
  const Migration20260603133701(),
  const Migration20260607174822(),
  const Migration20260613095807(),
  const Migration20260613154239(),
  const Migration20260613162843(),
  const Migration20260614125205(),
  const Migration20260614145507(),
  const Migration20260615000000(),
  const Migration20260615060000(),
  const Migration20260615204827(),
  const Migration20260615211634(),
  const Migration20260616180151(),
  const Migration20260616230747(),
  const Migration20260617195026(),
  const Migration20260620084032(),
  const Migration20260620095103(),
};

/// A consumable database structure including the latest generated migration.
final schema = Schema(
  20260725185723,
  generatorVersion: 1,
  tables: <SchemaTable>{
    SchemaTable(
      'OfflineAccount',
      columns: <SchemaColumn>{
        SchemaColumn(
          '_brick_id',
          Column.integer,
          autoincrement: true,
          nullable: false,
          isPrimaryKey: true,
        ),
        SchemaColumn('id', Column.varchar, unique: true),
        SchemaColumn('user_id', Column.varchar),
        SchemaColumn('name', Column.varchar),
        SchemaColumn('type', Column.varchar),
        SchemaColumn('currency', Column.varchar),
        SchemaColumn('current_balance', Column.varchar),
        SchemaColumn('institution', Column.varchar),
        SchemaColumn('include_in_net_worth', Column.boolean),
        SchemaColumn('is_active', Column.boolean),
        SchemaColumn('details_json', Column.varchar),
        SchemaColumn('goal_target_amount', Column.varchar),
        SchemaColumn('goal_target_date', Column.datetime),
        SchemaColumn('goal_priority', Column.varchar),
        SchemaColumn('updated_at', Column.datetime),
        SchemaColumn('version', Column.integer),
      },
      indices: <SchemaIndex>{
        SchemaIndex(columns: ['user_id'], unique: false),
      },
    ),
    SchemaTable(
      'OfflineCategory',
      columns: <SchemaColumn>{
        SchemaColumn(
          '_brick_id',
          Column.integer,
          autoincrement: true,
          nullable: false,
          isPrimaryKey: true,
        ),
        SchemaColumn('id', Column.varchar, unique: true),
        SchemaColumn('user_id', Column.varchar),
        SchemaColumn('template_id', Column.varchar),
        SchemaColumn('name', Column.varchar),
        SchemaColumn('type', Column.varchar),
        SchemaColumn('category_group', Column.varchar),
        SchemaColumn('group_id', Column.varchar),
        SchemaColumn('parent_id', Column.varchar),
        SchemaColumn('icon', Column.varchar),
        SchemaColumn('color', Column.varchar),
        SchemaColumn('budget_enabled', Column.boolean),
        SchemaColumn('is_active', Column.boolean),
        SchemaColumn('created_at', Column.datetime),
        SchemaColumn('budget_amount', Column.varchar),
        SchemaColumn('budget_currency', Column.varchar),
        SchemaColumn('budget_period', Column.varchar),
        SchemaColumn('budget_rollover', Column.boolean),
        SchemaColumn('alert_thresholds', Column.varchar),
        SchemaColumn('updated_at', Column.datetime),
        SchemaColumn('version', Column.integer),
      },
      indices: <SchemaIndex>{
        SchemaIndex(columns: ['user_id'], unique: false),
      },
    ),
    SchemaTable(
      'OfflineCategoryGroup',
      columns: <SchemaColumn>{
        SchemaColumn(
          '_brick_id',
          Column.integer,
          autoincrement: true,
          nullable: false,
          isPrimaryKey: true,
        ),
        SchemaColumn('id', Column.varchar, unique: true),
        SchemaColumn('user_id', Column.varchar),
        SchemaColumn('template_id', Column.varchar),
        SchemaColumn('name', Column.varchar),
        SchemaColumn('icon', Column.varchar),
        SchemaColumn('color', Column.varchar),
        SchemaColumn('sort_order', Column.integer),
        SchemaColumn('created_at', Column.datetime),
        SchemaColumn('budget_amount', Column.varchar),
        SchemaColumn('budget_currency', Column.varchar),
        SchemaColumn('updated_at', Column.datetime),
        SchemaColumn('version', Column.integer),
      },
      indices: <SchemaIndex>{
        SchemaIndex(columns: ['user_id'], unique: false),
      },
    ),
    SchemaTable(
      'OfflineInvestmentHolding',
      columns: <SchemaColumn>{
        SchemaColumn(
          '_brick_id',
          Column.integer,
          autoincrement: true,
          nullable: false,
          isPrimaryKey: true,
        ),
        SchemaColumn('id', Column.varchar, unique: true),
        SchemaColumn('user_id', Column.varchar),
        SchemaColumn('symbol', Column.varchar),
        SchemaColumn('asset_class', Column.varchar),
        SchemaColumn('quantity', Column.varchar),
        SchemaColumn('average_cost', Column.varchar),
        SchemaColumn('current_price', Column.varchar),
        SchemaColumn('currency', Column.varchar),
        SchemaColumn('market_value', Column.varchar),
        SchemaColumn('target_allocation_percent', Column.Double),
        SchemaColumn('created_at', Column.datetime),
        SchemaColumn('updated_at', Column.datetime),
        SchemaColumn('version', Column.integer),
      },
      indices: <SchemaIndex>{
        SchemaIndex(columns: ['user_id'], unique: false),
      },
    ),
    SchemaTable(
      'OfflineProfile',
      columns: <SchemaColumn>{
        SchemaColumn(
          '_brick_id',
          Column.integer,
          autoincrement: true,
          nullable: false,
          isPrimaryKey: true,
        ),
        SchemaColumn('id', Column.varchar, unique: true),
        SchemaColumn('display_name', Column.varchar),
        SchemaColumn('email', Column.varchar),
        SchemaColumn('base_currency', Column.varchar),
        SchemaColumn('country', Column.varchar),
        SchemaColumn('timezone', Column.varchar),
        SchemaColumn('preferred_theme', Column.varchar),
        SchemaColumn('aiko_character_visibility', Column.varchar),
        SchemaColumn('aiko_personality_setting', Column.varchar),
        SchemaColumn('security_status', Column.varchar),
        SchemaColumn('full_name', Column.varchar),
        SchemaColumn('gender', Column.varchar),
        SchemaColumn('date_of_birth', Column.datetime),
        SchemaColumn('phone_number', Column.varchar),
        SchemaColumn('avatar_path', Column.varchar),
        SchemaColumn('avatar_url', Column.varchar),
        SchemaColumn('updated_at', Column.datetime),
        SchemaColumn('version', Column.integer),
      },
      indices: <SchemaIndex>{},
    ),
    SchemaTable(
      'OfflineTransaction',
      columns: <SchemaColumn>{
        SchemaColumn(
          '_brick_id',
          Column.integer,
          autoincrement: true,
          nullable: false,
          isPrimaryKey: true,
        ),
        SchemaColumn('id', Column.varchar, unique: true),
        SchemaColumn('user_id', Column.varchar),
        SchemaColumn('account_id', Column.varchar),
        SchemaColumn('type', Column.varchar),
        SchemaColumn('amount', Column.varchar),
        SchemaColumn('currency', Column.varchar),
        SchemaColumn('date', Column.datetime),
        SchemaColumn('category_id', Column.varchar),
        SchemaColumn('merchant', Column.varchar),
        SchemaColumn('note', Column.varchar),
        SchemaColumn('tags', Column.varchar),
        SchemaColumn('status', Column.varchar),
        SchemaColumn('is_recurring', Column.boolean),
        SchemaColumn('recurring_frequency', Column.varchar),
        SchemaColumn('recurring_end_date', Column.datetime),
        SchemaColumn('recurring_max_occurrences', Column.integer),
        SchemaColumn('recurring_day_of_week', Column.integer),
        SchemaColumn('recurring_day_of_month', Column.integer),
        SchemaColumn('recurring_month_of_year', Column.integer),
        SchemaColumn('reminder_at', Column.datetime),
        SchemaColumn('updated_at', Column.datetime),
        SchemaColumn('version', Column.integer),
      },
      indices: <SchemaIndex>{
        SchemaIndex(columns: ['user_id'], unique: false),
        SchemaIndex(columns: ['account_id'], unique: false),
      },
    ),
  },
);
