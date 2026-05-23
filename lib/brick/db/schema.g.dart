// GENERATED CODE DO NOT EDIT
// This file should be version controlled
import 'package:brick_sqlite/db.dart';
part '20260523055312.migration.dart';

/// All intelligently-generated migrations from all `@Migratable` classes on disk
final migrations = <Migration>{const Migration20260523055312()};

/// A consumable database structure including the latest generated migration.
final schema = Schema(
  20260523055312,
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
        SchemaColumn('opening_balance', Column.varchar),
        SchemaColumn('current_balance', Column.varchar),
        SchemaColumn('institution', Column.varchar),
        SchemaColumn('include_in_net_worth', Column.boolean),
        SchemaColumn('is_active', Column.boolean),
      },
      indices: <SchemaIndex>{
        SchemaIndex(columns: ['user_id'], unique: false),
      },
    ),
    SchemaTable(
      'OfflineBudget',
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
        SchemaColumn('category_id', Column.varchar),
        SchemaColumn('amount', Column.varchar),
        SchemaColumn('currency', Column.varchar),
        SchemaColumn('period_start', Column.datetime),
        SchemaColumn('period_end', Column.datetime),
        SchemaColumn('period', Column.varchar),
        SchemaColumn('alert_thresholds', Column.varchar),
        SchemaColumn('status', Column.varchar),
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
        SchemaColumn('name', Column.varchar),
        SchemaColumn('type', Column.varchar),
        SchemaColumn('category_group', Column.varchar),
        SchemaColumn('parent_id', Column.varchar),
        SchemaColumn('icon', Column.varchar),
        SchemaColumn('color', Column.varchar),
        SchemaColumn('budget_enabled', Column.boolean),
        SchemaColumn('is_active', Column.boolean),
      },
      indices: <SchemaIndex>{
        SchemaIndex(columns: ['user_id'], unique: false),
      },
    ),
    SchemaTable(
      'OfflineGoal',
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
        SchemaColumn('purpose', Column.varchar),
        SchemaColumn('target_amount', Column.varchar),
        SchemaColumn('current_amount', Column.varchar),
        SchemaColumn('currency', Column.varchar),
        SchemaColumn('target_date', Column.datetime),
        SchemaColumn('linked_account_id', Column.varchar),
        SchemaColumn('priority', Column.integer),
        SchemaColumn('success_probability', Column.Double),
        SchemaColumn('status', Column.varchar),
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
        SchemaColumn('ai_consent_enabled', Column.boolean),
        SchemaColumn('onboarding_status', Column.varchar),
        SchemaColumn('security_status', Column.varchar),
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
      },
      indices: <SchemaIndex>{
        SchemaIndex(columns: ['user_id'], unique: false),
        SchemaIndex(columns: ['account_id'], unique: false),
      },
    ),
  },
);
