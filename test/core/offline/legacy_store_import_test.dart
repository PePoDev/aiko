import 'dart:io';

import 'package:aiko/core/offline/legacy_store_import.dart';
import 'package:aiko/core/offline/offline_store.dart';
import 'package:aiko/core/offline/records/records.dart';
import 'package:aiko/core/storage/local_record_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'record_store_harness.dart';

// The tables of the old app's last local schema (Brick's generated schema,
// version 20261010120000), as Brick created them: an integer `_brick_id` key,
// booleans as 0/1, dates and decimals as text and lists as JSON text.
const _latestSchema = [
  'CREATE TABLE MigrationVersions (version INTEGER PRIMARY KEY)',
  'INSERT INTO MigrationVersions (version) VALUES (20261010120000)',
  '''CREATE TABLE `OfflineAccount` (
    `_brick_id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
    `id` VARCHAR UNIQUE, `user_id` VARCHAR, `name` VARCHAR, `type` VARCHAR,
    `currency` VARCHAR, `current_balance` VARCHAR, `institution` VARCHAR,
    `include_in_net_worth` BOOLEAN, `is_active` BOOLEAN, `details_json` VARCHAR,
    `goal_target_amount` VARCHAR, `goal_target_date` DATETIME,
    `goal_priority` VARCHAR, `updated_at` DATETIME, `version` INTEGER)''',
  '''CREATE TABLE `OfflineCategory` (
    `_brick_id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
    `id` VARCHAR UNIQUE, `user_id` VARCHAR, `template_id` VARCHAR,
    `name` VARCHAR, `type` VARCHAR, `category_group` VARCHAR,
    `group_id` VARCHAR, `parent_id` VARCHAR, `icon` VARCHAR, `color` VARCHAR,
    `budget_enabled` BOOLEAN, `is_active` BOOLEAN, `created_at` DATETIME,
    `budget_amount` VARCHAR, `budget_currency` VARCHAR,
    `budget_period` VARCHAR, `budget_rollover` BOOLEAN,
    `alert_thresholds` VARCHAR, `updated_at` DATETIME, `version` INTEGER)''',
  '''CREATE TABLE `OfflineCategoryGroup` (
    `_brick_id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
    `id` VARCHAR UNIQUE, `user_id` VARCHAR, `template_id` VARCHAR,
    `name` VARCHAR, `icon` VARCHAR, `color` VARCHAR, `sort_order` INTEGER,
    `created_at` DATETIME, `budget_amount` VARCHAR, `budget_currency` VARCHAR,
    `updated_at` DATETIME, `version` INTEGER)''',
  '''CREATE TABLE `OfflineInvestmentHolding` (
    `_brick_id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
    `id` VARCHAR UNIQUE, `user_id` VARCHAR, `symbol` VARCHAR,
    `asset_class` VARCHAR, `quantity` VARCHAR, `average_cost` VARCHAR,
    `current_price` VARCHAR, `currency` VARCHAR, `market_value` VARCHAR,
    `target_allocation_percent` DOUBLE, `created_at` DATETIME,
    `updated_at` DATETIME, `version` INTEGER)''',
  '''CREATE TABLE `OfflineProfile` (
    `_brick_id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
    `id` VARCHAR UNIQUE, `display_name` VARCHAR, `email` VARCHAR,
    `base_currency` VARCHAR, `country` VARCHAR, `timezone` VARCHAR,
    `preferred_theme` VARCHAR, `aiko_character_visibility` VARCHAR,
    `aiko_personality_setting` VARCHAR, `security_status` VARCHAR,
    `full_name` VARCHAR, `gender` VARCHAR, `date_of_birth` DATETIME,
    `phone_number` VARCHAR, `avatar_path` VARCHAR, `avatar_url` VARCHAR,
    `updated_at` DATETIME, `version` INTEGER)''',
  '''CREATE TABLE `OfflineTransaction` (
    `_brick_id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
    `id` VARCHAR UNIQUE, `user_id` VARCHAR, `account_id` VARCHAR,
    `type` VARCHAR, `amount` VARCHAR, `currency` VARCHAR, `date` DATETIME,
    `category_id` VARCHAR, `merchant` VARCHAR, `note` VARCHAR, `tags` VARCHAR,
    `status` VARCHAR, `is_recurring` BOOLEAN, `recurring_frequency` VARCHAR,
    `recurring_end_date` DATETIME, `recurring_max_occurrences` INTEGER,
    `recurring_day_of_week` INTEGER, `recurring_day_of_month` INTEGER,
    `recurring_month_of_year` INTEGER, `reminder_at` DATETIME,
    `transfer_group_id` VARCHAR, `updated_at` DATETIME, `version` INTEGER)''',
];

const _owner = 'local:guest';

final _latestRows = <String, List<Map<String, Object?>>>{
  'OfflineAccount': [
    {
      'id': 'acc-card',
      'user_id': _owner,
      'name': 'Visa',
      'type': 'creditCard',
      'currency': 'THB',
      'current_balance': '-1250.50',
      'institution': 'KBank',
      'include_in_net_worth': 1,
      'is_active': 0,
      'details_json':
          '{"_type":"creditCard","creditLimit":{"amount":"50000","currency":"THB"},"statementDay":25,"dueDay":10}',
      'goal_target_amount': null,
      'goal_target_date': null,
      'goal_priority': 'medium',
      'updated_at': '2026-09-01T10:00:00.000Z',
      'version': 4,
    },
    {
      'id': 'acc-goal',
      'user_id': _owner,
      'name': 'Japan trip',
      'type': 'goal',
      'currency': 'THB',
      'current_balance': '12000',
      'include_in_net_worth': 1,
      'is_active': 1,
      'details_json': null,
      'goal_target_amount': '80000',
      'goal_target_date': '2027-04-01T00:00:00.000',
      'goal_priority': 'high',
      'updated_at': '2026-09-01T10:00:00.000Z',
      'version': 1,
    },
  ],
  'OfflineCategory': [
    {
      'id': 'cat-plants',
      'user_id': _owner,
      'template_id': null,
      'name': 'Plants',
      'type': 'expense',
      'category_group': 'wants',
      'group_id': 'group-home',
      'parent_id': null,
      'icon': 'eco',
      'color': '#22AA55',
      'budget_enabled': 1,
      'is_active': 1,
      'created_at': '2026-06-01T00:00:00.000Z',
      'budget_amount': '800',
      'budget_currency': 'THB',
      'budget_period': 'weekly',
      'budget_rollover': 1,
      'alert_thresholds': '[80,100]',
      'updated_at': '2026-09-01T10:00:00.000Z',
      'version': 1,
    },
  ],
  'OfflineCategoryGroup': [
    {
      'id': 'group-home',
      'user_id': _owner,
      'template_id': null,
      'name': 'Home',
      'icon': 'home',
      'color': '#123456',
      'sort_order': 3,
      'created_at': '2026-06-01T00:00:00.000Z',
      'budget_amount': null,
      'budget_currency': null,
      'updated_at': '2026-09-01T10:00:00.000Z',
      'version': 1,
    },
  ],
  'OfflineInvestmentHolding': [
    {
      'id': 'holding-vti',
      'user_id': _owner,
      'symbol': 'VTI',
      'asset_class': 'etf',
      'quantity': '12.5',
      'average_cost': '210.10',
      'current_price': '250',
      'currency': 'USD',
      'market_value': '3125',
      'target_allocation_percent': 40.5,
      'created_at': '2026-06-01T00:00:00.000Z',
      'updated_at': '2026-09-01T10:00:00.000Z',
      'version': 1,
    },
  ],
  'OfflineProfile': [
    {
      'id': _owner,
      'display_name': 'Aiko',
      'email': '',
      'base_currency': 'JPY',
      'country': 'JP',
      'timezone': 'Asia/Tokyo',
      'preferred_theme': 'dark',
      'aiko_character_visibility': 'full',
      'aiko_personality_setting': 'supportive',
      'security_status': 'notConfigured',
      'full_name': null,
      'gender': null,
      'date_of_birth': null,
      'phone_number': null,
      'avatar_path': null,
      'avatar_url': null,
      'updated_at': '2026-09-01T10:00:00.000Z',
      'version': 1,
    },
  ],
  'OfflineTransaction': [
    {
      'id': 'tx-out',
      'user_id': _owner,
      'account_id': 'acc-card',
      'type': 'transferOut',
      'amount': '300',
      'currency': 'THB',
      'date': '2026-09-02T08:30:00.000',
      'category_id': null,
      'merchant': 'Transfer to Japan trip',
      'note': '',
      'tags': '["trip","saving"]',
      'status': 'posted',
      'is_recurring': 1,
      'recurring_frequency': 'monthly',
      'recurring_end_date': null,
      'recurring_max_occurrences': 12,
      'recurring_day_of_week': null,
      'recurring_day_of_month': 2,
      'recurring_month_of_year': null,
      'reminder_at': '2026-09-02T09:00:00.000',
      'transfer_group_id': 'pair-1',
      'updated_at': '2026-09-02T08:30:00.000Z',
      'version': 1,
    },
    {
      'id': 'tx-coffee',
      'user_id': _owner,
      'account_id': 'acc-card',
      'type': 'expense',
      'amount': '65.5',
      'currency': 'THB',
      'date': '2026-09-03T07:00:00.000',
      'category_id': 'cat-plants',
      'merchant': 'Cafe',
      'note': null,
      'tags': '[]',
      'status': 'posted',
      'is_recurring': 0,
      'transfer_group_id': null,
      'updated_at': '2026-09-03T07:00:00.000Z',
      'version': 1,
    },
  ],
};

void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfiNoIsolate;
  late Directory dir;
  late String legacyPath;
  late LocalRecordStore target;
  late OfflineStore records;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('aiko-legacy-');
    legacyPath = '${dir.path}/${LegacyStoreImport.legacyFileName}';
    target = await openMemoryRecordStore();
    records = OfflineStore(local: target, signedInUserId: () => null);
  });

  tearDown(() async {
    await target.close();
    await dir.delete(recursive: true);
  });

  Future<void> createLegacy(
    List<String> schema,
    Map<String, List<Map<String, Object?>>> rows,
  ) async {
    final db = await factory.openDatabase(legacyPath);
    for (final statement in schema) {
      await db.execute(statement);
    }
    for (final entry in rows.entries) {
      for (final row in entry.value) {
        await db.insert(entry.key, row);
      }
    }
    await db.close();
  }

  LegacyStoreImport importer() => LegacyStoreImport(
    target: target,
    factory: factory,
    legacyPath: legacyPath,
  );

  test('imports every record type and retires the old database', () async {
    await createLegacy(_latestSchema, _latestRows);

    expect(await importer().run(), 8);

    expect(await factory.databaseExists(legacyPath), isFalse);
    final accounts = {
      for (final a in await records.get<OfflineAccount>()) a.id: a,
    };
    final card = accounts['acc-card']!;
    expect(card.currentBalance, '-1250.50');
    expect(card.includeInNetWorth, isTrue);
    expect(card.isActive, isFalse);
    expect(card.version, 4);
    final details = card.toDomain().details;
    expect(details?.variantName, 'creditCard');
    expect(accountDetailsToRow(card.detailsJson)['statementDay'], 25);
    final goal = accounts['acc-goal']!;
    expect(goal.detailsJson, '{}');
    expect(goal.goalTargetAmount, '80000');
    expect(goal.goalTargetDate, DateTime(2027, 4, 1));
    expect(goal.goalPriority, 'high');

    final category = (await records.get<OfflineCategory>()).single;
    expect(category.budgetEnabled, isTrue);
    expect(category.budgetRollover, isTrue);
    expect(category.alertThresholds, [80, 100]);
    expect(category.budgetPeriod, 'weekly');
    expect(category.groupId, 'group-home');
    expect(category.createdAt, DateTime.utc(2026, 6, 1));

    final group = (await records.get<OfflineCategoryGroup>()).single;
    expect(group.sortOrder, 3);
    expect(group.ownerId, _owner);

    final holding = (await records.get<OfflineInvestmentHolding>()).single;
    expect(holding.targetAllocationPercent, 40.5);
    expect(holding.quantity, '12.5');

    final profile = (await records.get<OfflineProfile>()).single;
    expect(profile.baseCurrency, 'JPY');
    expect(profile.gender, 'preferNotToSay');
    expect(profile.ownerId, _owner);

    final transactions = {
      for (final t in await records.get<OfflineTransaction>(
        query: const RecordQuery(ownerId: _owner),
      ))
        t.id: t,
    };
    final out = transactions['tx-out']!;
    expect(out.tags, ['trip', 'saving']);
    expect(out.isRecurring, isTrue);
    expect(out.recurringMaxOccurrences, 12);
    expect(out.recurringDayOfMonth, 2);
    expect(out.reminderAt, DateTime(2026, 9, 2, 9));
    expect(out.transferGroupId, 'pair-1');
    expect(out.date, DateTime(2026, 9, 2, 8, 30));
    final coffee = transactions['tx-coffee']!;
    expect(coffee.tags, isEmpty);
    expect(coffee.isRecurring, isFalse);
    expect(coffee.note, isNull);
    expect(coffee.amount, '65.5');
  });

  test('without an old database nothing happens', () async {
    expect(await importer().run(), 0);
    expect(await target.rows('accounts'), isEmpty);
    expect(await factory.databaseExists(legacyPath), isFalse);
  });

  test(
    'runs once: a leftover old database is deleted, not imported again',
    () async {
      await createLegacy(_latestSchema, _latestRows);
      expect(await importer().run(), 8);
      // The user deletes a record after the import...
      await records.delete(
        (await records.get<OfflineTransaction>(
          query: const RecordQuery(id: 'tx-coffee'),
        )).single,
      );
      // ...and the old file is still there (the app stopped before deleting it).
      await createLegacy(_latestSchema, _latestRows);

      expect(await importer().run(), 0);

      expect(await factory.databaseExists(legacyPath), isFalse);
      expect((await records.get<OfflineTransaction>()).map((t) => t.id), [
        'tx-out',
      ]);
    },
  );

  test(
    'an interrupted import re-runs without overwriting newer records',
    () async {
      await createLegacy(_latestSchema, _latestRows);
      // Written before the import completed (a previous attempt failed): the
      // newer copy wins.
      await records.upsert(
        OfflineAccount(
          id: 'acc-card',
          userId: _owner,
          name: 'Visa (renamed)',
          type: 'creditCard',
          currency: 'THB',
          currentBalance: '-10',
        ),
      );

      expect(await importer().run(), 8);

      final accounts = await records.get<OfflineAccount>();
      expect(accounts, hasLength(2));
      expect(
        accounts.singleWhere((a) => a.id == 'acc-card').name,
        'Visa (renamed)',
      );
    },
  );

  test(
    'tolerates an old schema with missing tables, columns and values',
    () async {
      await createLegacy(
        [
          // Before investments, groups, template ids, recurring fields,
          // transfer links, updated_at and version existed; with the budget
          // table that a later version dropped.
          '''CREATE TABLE `OfflineAccount` (
          `_brick_id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
          `id` VARCHAR UNIQUE, `user_id` VARCHAR, `name` VARCHAR,
          `type` VARCHAR, `currency` VARCHAR, `opening_balance` VARCHAR,
          `current_balance` VARCHAR, `institution` VARCHAR,
          `include_in_net_worth` BOOLEAN, `is_active` BOOLEAN)''',
          '''CREATE TABLE `OfflineCategory` (
          `_brick_id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
          `id` VARCHAR UNIQUE, `user_id` VARCHAR, `name` VARCHAR,
          `type` VARCHAR, `category_group` VARCHAR, `parent_id` VARCHAR,
          `icon` VARCHAR, `color` VARCHAR, `budget_enabled` BOOLEAN,
          `is_active` BOOLEAN)''',
          '''CREATE TABLE `OfflineTransaction` (
          `_brick_id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
          `id` VARCHAR UNIQUE, `user_id` VARCHAR, `account_id` VARCHAR,
          `type` VARCHAR, `amount` VARCHAR, `currency` VARCHAR,
          `date` DATETIME, `category_id` VARCHAR, `merchant` VARCHAR,
          `note` VARCHAR, `tags` VARCHAR, `status` VARCHAR)''',
          '''CREATE TABLE `OfflineBudget` (
          `_brick_id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
          `id` VARCHAR UNIQUE, `amount` VARCHAR)''',
        ],
        {
          'OfflineAccount': [
            {
              'id': 'acc-cash',
              'user_id': _owner,
              'name': 'Cash',
              'type': 'cash',
              'currency': 'THB',
              'opening_balance': '0',
              'current_balance': '150',
              'include_in_net_worth': 1,
              'is_active': 1,
            },
          ],
          'OfflineCategory': [
            {
              'id': 'cat-old',
              'user_id': _owner,
              'name': 'Old',
              'type': 'expense',
              'category_group': 'needs',
              'icon': null,
              'color': null,
              'budget_enabled': 1,
              'is_active': 1,
            },
          ],
          'OfflineTransaction': [
            {
              'id': 'tx-old',
              'user_id': _owner,
              'account_id': 'acc-cash',
              'type': 'expense',
              'amount': '20',
              'currency': 'THB',
              'date': '2026-05-01T12:00:00.000',
              'tags': null,
              'status': null,
            },
            // Unreadable rows (no id, no date) are left behind.
            {'id': null, 'user_id': _owner, 'amount': '1'},
            {
              'id': 'tx-no-date',
              'user_id': _owner,
              'account_id': 'acc-cash',
              'type': 'expense',
              'amount': '5',
              'currency': 'THB',
            },
          ],
          'OfflineBudget': [
            {'id': 'budget', 'amount': '100'},
          ],
        },
      );

      expect(await importer().run(), 3);

      final account = (await records.get<OfflineAccount>()).single;
      expect(account.currentBalance, '150');
      expect(account.detailsJson, '{}');
      expect(account.goalPriority, 'medium');
      expect(account.version, 1);
      final category = (await records.get<OfflineCategory>()).single;
      expect(category.icon, 'category');
      expect(category.templateId, isNull);
      expect(category.budgetPeriod, 'monthly');
      expect(category.alertThresholds, [50, 75, 90, 100]);
      final transaction = (await records.get<OfflineTransaction>()).single;
      expect(transaction.id, 'tx-old');
      expect(transaction.tags, isEmpty);
      expect(transaction.status, 'posted');
      expect(transaction.transferGroupId, isNull);
      expect(transaction.reminderAt, isNull);
      expect(await factory.databaseExists(legacyPath), isFalse);
    },
  );
}
