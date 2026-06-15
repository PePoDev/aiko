import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

/// One-time migration that rewrites the legacy `budgets` rows into the
/// per-category budget fields on `categories`, and the legacy `goals` rows
/// into `accounts` with `type = 'goal'`.
///
/// Per the merge plan: the app is pre-launch and the user picked "same
/// release" (no dual-read window), so this runs once on startup, marks
/// itself done, and the legacy rows are removed from the schema in PR5.
///
/// Implementation: uses the [sqflite] `databaseFactory` directly with the
/// same `aiko_offline.sqlite` path the Brick repository uses, so the
/// migration can read/write rows before the `OfflineBudget` / `OfflineGoal`
/// adapters are dropped from the codebase.
class BudgetGoalMigrator {
  BudgetGoalMigrator();

  static const _dbPath = 'aiko_offline.sqlite';
  static const _metaKey = 'budget_goal_merge_v1';
  static const _metaTable = '_aiko_migration_meta';
  static const _done = 'done';

  /// Idempotent. Returns the number of (budget, goal) rows merged.
  Future<({int budgets, int goals})> runIfNeeded() async {
    final db = await _openDb();
    if (db == null) {
      return (budgets: 0, goals: 0);
    }
    try {
      if (await _isDone(db)) {
        return (budgets: 0, goals: 0);
      }
      final budgets = await _mergeBudgets(db);
      final goals = await _mergeGoals(db);
      await _markDone(db);
      if (kDebugMode) {
        debugPrint(
          '[aiko-migration] budgets->categories: $budgets, '
          'goals->accounts: $goals',
        );
      }
      return (budgets: budgets, goals: goals);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[aiko-migration] run failed: $error');
      }
      return (budgets: 0, goals: 0);
    } finally {
      await db.close();
    }
  }

  Future<Database?> _openDb() async {
    try {
      final factory = databaseFactory;
      // Open the same SQLite file Brick uses. The migrations are applied
      // before this point by AikoBrickRepository.configure() so the new
      // `categories` and `accounts` columns exist.
      return factory.openDatabase(
        _dbPath,
        options: OpenDatabaseOptions(readOnly: false),
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[aiko-migration] open db failed: $error');
      }
      return null;
    }
  }

  Future<bool> _isDone(Database db) async {
    try {
      await db.execute(
        'create table if not exists $_metaTable '
        '(key text primary key, value text)',
      );
      final rows = await db.query(
        _metaTable,
        columns: const ['value'],
        where: 'key = ?',
        whereArgs: [_metaKey],
        limit: 1,
      );
      if (rows.isEmpty) return false;
      return rows.first['value'] == _done;
    } catch (_) {
      return false;
    }
  }

  Future<void> _markDone(Database db) async {
    try {
      await db.insert(_metaTable, {
        'key': _metaKey,
        'value': _done,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[aiko-migration] mark done failed: $error');
      }
    }
  }

  Future<int> _mergeBudgets(Database db) async {
    try {
      // A fresh install that has not had legacy rows never has this table;
      // treat as "nothing to migrate".
      final legacyRows = await db.rawQuery(
        'select category_id, amount, currency, period, alert_thresholds '
        'from OfflineBudget '
        "where category_id is not null and (status = 'active' or status is null)",
      );
      if (legacyRows.isEmpty) return 0;

      final byCategory = <String, List<Map<String, Object?>>>{};
      for (final row in legacyRows) {
        final cid = row['category_id'] as String;
        byCategory.putIfAbsent(cid, () => []).add(row);
      }

      var touched = 0;
      for (final entry in byCategory.entries) {
        final categoryRows = await db.query(
          'OfflineCategory',
          columns: const ['id'],
          where: 'id = ?',
          whereArgs: [entry.key],
          limit: 1,
        );
        if (categoryRows.isEmpty) continue;
        // Take the max amount so multiple legacy rows per category collapse
        // to the largest limit (a user-defined 50/30/20 + an app-defined
        // Daily Spending).
        final amounts = entry.value
            .map((r) => num.tryParse(r['amount'] as String) ?? 0)
            .where((n) => n > 0)
            .toList();
        if (amounts.isEmpty) continue;
        final amount = amounts.reduce((a, b) => a > b ? a : b).toString();
        final currency = entry.value.first['currency'] as String;
        final periods = entry.value.map((r) => r['period'] as String).toList();
        final period = periods.contains('monthly')
            ? 'monthly'
            : periods.contains('weekly')
            ? 'weekly'
            : periods.contains('yearly')
            ? 'yearly'
            : periods.contains('daily')
            ? 'daily'
            : 'monthly';
        final thresholds = <int>{};
        for (final r in entry.value) {
          thresholds.addAll(_decodeThresholds(r['alert_thresholds']));
        }
        final thresholdList = thresholds.toList()..sort();
        await db.update(
          'OfflineCategory',
          {
            'budget_amount': amount,
            'budget_currency': currency,
            'budget_period': period,
            'budget_rollover': 0,
            'alert_thresholds': _encodeThresholds(
              thresholdList.isEmpty ? [50, 75, 90, 100] : thresholdList,
            ),
          },
          where: 'id = ?',
          whereArgs: [entry.key],
        );
        touched++;
      }
      return touched;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[aiko-migration] budget merge failed: $error');
      }
      return 0;
    }
  }

  Future<int> _mergeGoals(Database db) async {
    try {
      final goals = await db.rawQuery(
        'select id, user_id, name, currency, current_amount, target_amount, '
        'target_date, priority from OfflineGoal',
      );
      if (goals.isEmpty) return 0;

      var touched = 0;
      for (final g in goals) {
        final existing = await db.query(
          'OfflineAccount',
          columns: const ['id'],
          where: 'id = ?',
          whereArgs: [g['id']],
          limit: 1,
        );
        if (existing.isNotEmpty) continue;
        final priority = _priorityOf((g['priority'] as int?) ?? 2);
        await db.insert('OfflineAccount', {
          'id': g['id'],
          'user_id': g['user_id'],
          'name': g['name'],
          'type': 'goal',
          'currency': g['currency'],
          'current_balance': g['current_amount'],
          'institution': null,
          'include_in_net_worth': 1,
          'is_active': 1,
          'details_json': '{}',
          'goal_target_amount': g['target_amount'],
          'goal_target_date': _toIsoDate(g['target_date']),
          'goal_priority': priority,
        });
        touched++;
      }
      return touched;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[aiko-migration] goal merge failed: $error');
      }
      return 0;
    }
  }
}

List<int> _decodeThresholds(Object? raw) {
  if (raw == null) return const [];
  if (raw is List) {
    return raw
        .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
        .where((e) => e > 0)
        .toList();
  }
  if (raw is String) {
    return raw
        .split(',')
        .map((e) => int.tryParse(e.trim()) ?? 0)
        .where((e) => e > 0)
        .toList();
  }
  return const [];
}

String _encodeThresholds(List<int> thresholds) => thresholds.join(',');

String? _toIsoDate(Object? raw) {
  if (raw == null) return null;
  if (raw is int) {
    // sqflite stores dates as millis since epoch.
    final dt = DateTime.fromMillisecondsSinceEpoch(raw);
    return dt.toIso8601String().substring(0, 10);
  }
  return raw.toString();
}

String _priorityOf(int priority) {
  if (priority >= 3) return 'high';
  if (priority <= 1) return 'low';
  return 'medium';
}
