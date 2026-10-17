import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' show Database, DatabaseFactory;

import '../config/app_config.dart';
import '../storage/database_factory.dart' as platform;
import '../storage/local_record_store.dart';
import 'record_batch.dart';
import 'records/records.dart';

/// Moves the records of the local database written by earlier versions of the
/// app (the Brick package's `aiko_offline.sqlite`: one table per record type,
/// one column per field) into the [LocalRecordStore], once.
///
/// Crash-safe and idempotent: every record and the "imported" mark go in one
/// transaction that keeps records already in the store, and the old database
/// is deleted only after that transaction has committed. An interrupted run
/// simply runs again on the next start.
class LegacyStoreImport {
  LegacyStoreImport({
    required LocalRecordStore target,
    DatabaseFactory? factory,
    this.legacyPath = legacyFileName,
  }) : _target = target,
       _factory = factory ?? platform.databaseFactory;

  /// The old database file (native) or IndexedDB entry (web).
  static const legacyFileName = 'aiko_offline.sqlite';

  final LocalRecordStore _target;
  final DatabaseFactory _factory;
  final String legacyPath;

  String get _doneKey => 'legacy_import:$legacyPath';

  /// Imports the old database if there is one. Returns the number of records
  /// read from it (0 when there is none or it was imported before). Never
  /// throws: a failed import is retried on the next start.
  Future<int> run() async {
    try {
      if (await _target.meta(_doneKey) != null) {
        await _retire();
        return 0;
      }
      if (!await _factory.databaseExists(legacyPath)) return 0;
      final writes = await _readLegacy();
      await _target.transaction((txn) async {
        for (final write in writes) {
          await txn.put(
            write.collection,
            write.id,
            write.ownerId,
            write.row!,
            replace: false,
          );
        }
        await txn.setMeta(_doneKey, DateTime.now().toUtc().toIso8601String());
      });
      await _retire();
      return writes.length;
    } catch (error) {
      debugPrint('[aiko-store] importing $legacyPath failed: $error');
      return 0;
    }
  }

  Future<List<RecordWrite>> _readLegacy() async {
    final db = await _factory.openDatabase(legacyPath);
    try {
      final writes = <RecordWrite>[];
      for (final table in _legacyTables) {
        writes.addAll(await _readTable(db, table));
      }
      return writes;
    } finally {
      await db.close();
    }
  }

  Future<List<RecordWrite>> _readTable(Database db, _LegacyTable table) async {
    final exists = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [table.name],
    );
    if (exists.isEmpty) return const [];
    final batch = RecordBatch();
    for (final row in await db.rawQuery('SELECT * FROM `${table.name}`')) {
      try {
        batch.upsert(table.decode(row));
      } catch (error) {
        // A row the old app couldn't have read either (missing id or a
        // required field); leave it behind rather than block the import.
        debugPrint('[aiko-store] skipped a ${table.name} row: $error');
      }
    }
    return batch.writes;
  }

  /// The old database is no longer needed once its records are imported.
  Future<void> _retire() async {
    try {
      if (await _factory.databaseExists(legacyPath)) {
        await _factory.deleteDatabase(legacyPath);
      }
    } catch (error) {
      // The import is marked done; deleting is retried on the next start.
      debugPrint('[aiko-store] deleting $legacyPath failed: $error');
    }
  }
}

class _LegacyTable {
  const _LegacyTable(this.name, this.decode);

  final String name;
  final OfflineRecord Function(Map<String, Object?> row) decode;
}

const _legacyTables = [
  _LegacyTable('OfflineAccount', _account),
  _LegacyTable('OfflineCategoryGroup', _categoryGroup),
  _LegacyTable('OfflineCategory', _category),
  _LegacyTable('OfflineTransaction', _transaction),
  _LegacyTable('OfflineInvestmentHolding', _holding),
  _LegacyTable('OfflineProfile', _profile),
];

// Decoders for the old tables' rows. They follow the old app's readers
// (booleans stored as 0/1, dates and decimals as text, lists as JSON text)
// and tolerate columns that are missing or NULL in databases that were never
// migrated to the old app's last schema.

OfflineAccount _account(Map<String, Object?> r) => OfflineAccount(
  id: _required(r, 'id'),
  userId: _required(r, 'user_id'),
  name: _required(r, 'name'),
  type: _required(r, 'type'),
  currency: _required(r, 'currency'),
  currentBalance: _required(r, 'current_balance'),
  institution: _string(r['institution']),
  includeInNetWorth: r['include_in_net_worth'] == 1,
  isActive: r['is_active'] == 1,
  detailsJson: r['details_json'] is String
      ? r['details_json']! as String
      : '{}',
  goalTargetAmount: _string(r['goal_target_amount']),
  goalTargetDate: _date(r['goal_target_date']),
  goalPriority: goalPriorityFromColumn(r['goal_priority']),
  updatedAt: _date(r['updated_at']),
  version: _int(r['version']) ?? 1,
);

OfflineCategory _category(Map<String, Object?> r) => OfflineCategory(
  id: _required(r, 'id'),
  userId: _required(r, 'user_id'),
  templateId: _string(r['template_id']),
  name: _required(r, 'name'),
  type: _required(r, 'type'),
  categoryGroup: _required(r, 'category_group'),
  groupId: _string(r['group_id']),
  parentId: _string(r['parent_id']),
  icon: _string(r['icon']) ?? 'category',
  color: _string(r['color']) ?? '#3B82F6',
  budgetEnabled: r['budget_enabled'] == 1,
  isActive: r['is_active'] == 1,
  createdAt: _date(r['created_at']),
  budgetAmount: _string(r['budget_amount']),
  budgetCurrency: _string(r['budget_currency']),
  budgetPeriod: budgetPeriodFromColumn(r['budget_period']),
  budgetRollover: r['budget_rollover'] == 1,
  alertThresholds: _thresholds(r['alert_thresholds']),
  updatedAt: _date(r['updated_at']),
  version: _int(r['version']) ?? 1,
);

OfflineCategoryGroup _categoryGroup(Map<String, Object?> r) =>
    OfflineCategoryGroup(
      id: _required(r, 'id'),
      userId: _string(r['user_id']),
      templateId: _string(r['template_id']),
      name: _required(r, 'name'),
      icon: _string(r['icon']) ?? 'category',
      color: _string(r['color']) ?? '#3B82F6',
      sortOrder: _int(r['sort_order']) ?? 0,
      createdAt: _date(r['created_at']),
      budgetAmount: _string(r['budget_amount']),
      budgetCurrency: _string(r['budget_currency']),
      updatedAt: _date(r['updated_at']),
      version: _int(r['version']) ?? 1,
    );

OfflineInvestmentHolding _holding(Map<String, Object?> r) =>
    OfflineInvestmentHolding(
      id: _required(r, 'id'),
      userId: _required(r, 'user_id'),
      symbol: _required(r, 'symbol'),
      assetClass: _required(r, 'asset_class'),
      quantity: _required(r, 'quantity'),
      averageCost: _required(r, 'average_cost'),
      currentPrice: _required(r, 'current_price'),
      currency: _required(r, 'currency'),
      marketValue: _required(r, 'market_value'),
      targetAllocationPercent: (r['target_allocation_percent'] as num?)
          ?.toDouble(),
      createdAt: _date(r['created_at']),
      updatedAt: _date(r['updated_at']),
      version: _int(r['version']) ?? 1,
    );

OfflineProfile _profile(Map<String, Object?> r) => OfflineProfile(
  id: _required(r, 'id'),
  displayName: _string(r['display_name']) ?? '',
  email: _string(r['email']) ?? '',
  baseCurrency: _string(r['base_currency']) ?? kDefaultBaseCurrency,
  country: _string(r['country']) ?? kDefaultCountry,
  timezone: _string(r['timezone']) ?? 'UTC',
  preferredTheme: _string(r['preferred_theme']) ?? 'system',
  aikoCharacterVisibility: _string(r['aiko_character_visibility']) ?? 'full',
  aikoPersonalitySetting:
      _string(r['aiko_personality_setting']) ?? 'supportive',
  securityStatus: _string(r['security_status']) ?? 'notConfigured',
  fullName: _string(r['full_name']),
  gender: genderFromColumn(r['gender']),
  dateOfBirth: _date(r['date_of_birth']),
  phoneNumber: _string(r['phone_number']),
  avatarPath: _string(r['avatar_path']),
  avatarUrl: _string(r['avatar_url']),
  updatedAt: _date(r['updated_at']),
  version: _int(r['version']) ?? 1,
);

OfflineTransaction _transaction(Map<String, Object?> r) => OfflineTransaction(
  id: _required(r, 'id'),
  userId: _required(r, 'user_id'),
  accountId: _required(r, 'account_id'),
  type: _required(r, 'type'),
  amount: _required(r, 'amount'),
  currency: _required(r, 'currency'),
  date: _date(r['date']) ?? (throw const FormatException('date is missing')),
  categoryId: _string(r['category_id']),
  merchant: _string(r['merchant']),
  note: _string(r['note']),
  tags: _tags(r['tags']),
  status: _string(r['status']) ?? 'posted',
  isRecurring: r['is_recurring'] == 1,
  recurringFrequency: _string(r['recurring_frequency']),
  recurringEndDate: _date(r['recurring_end_date']),
  recurringMaxOccurrences: _int(r['recurring_max_occurrences']),
  recurringDayOfWeek: _int(r['recurring_day_of_week']),
  recurringDayOfMonth: _int(r['recurring_day_of_month']),
  recurringMonthOfYear: _int(r['recurring_month_of_year']),
  reminderAt: _date(r['reminder_at']),
  transferGroupId: _string(r['transfer_group_id']),
  updatedAt: _date(r['updated_at']),
  version: _int(r['version']) ?? 1,
);

String _required(Map<String, Object?> row, String column) =>
    _string(row[column]) ?? (throw FormatException('$column is missing'));

/// Text columns; decimals written as numbers by hand-made rows become text.
String? _string(Object? raw) => switch (raw) {
  null => null,
  String() => raw,
  num() => raw.toString(),
  _ => null,
};

int? _int(Object? raw) => raw is num ? raw.toInt() : null;

DateTime? _date(Object? raw) => raw is String ? DateTime.tryParse(raw) : null;

List<String> _tags(Object? raw) {
  if (raw is! String || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) return [for (final tag in decoded) tag.toString()];
  } catch (_) {}
  return const [];
}

List<int> _thresholds(Object? raw) {
  try {
    return alertThresholdsFromColumn(raw);
  } catch (_) {
    return const [50, 75, 90, 100];
  }
}
