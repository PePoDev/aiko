import 'dart:convert';

import 'package:brick_offline_first_with_supabase/brick_offline_first_with_supabase.dart';
import 'package:brick_sqlite/brick_sqlite.dart';
import 'package:brick_supabase/brick_supabase.dart';

@ConnectOfflineFirstWithSupabase(
  supabaseConfig: SupabaseSerializable(tableName: 'accounts'),
)
class OfflineAccount extends OfflineFirstWithSupabaseModel {
  OfflineAccount({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.currency,
    required this.currentBalance,
    this.institution,
    this.includeInNetWorth = true,
    this.isActive = true,
    this.detailsJson = '{}',
    this.goalTargetAmount,
    this.goalTargetDate,
    this.goalPriority = 'medium',
    DateTime? updatedAt,
    this.deletedAt,
    this.version = 1,
  }) : updatedAt = updatedAt ?? DateTime.now().toUtc();

  @Sqlite(unique: true)
  @Supabase(unique: true)
  final String id;

  @Sqlite(index: true)
  final String userId;

  final String name;
  final String type;
  final String currency;

  @Supabase(fromGenerator: 'data[\'current_balance\'].toString()')
  final String currentBalance;

  final String? institution;
  final bool includeInNetWorth;
  final bool isActive;

  // Stored locally as a JSON string but as a `jsonb` (Map) column named
  // `details` in Supabase. The generators below keep the conversion regen-safe:
  // - Supabase read/write goes through [accountDetailsFromSupabase] /
  //   [accountDetailsToSupabase] so the jsonb Map round-trips to/from a String.
  // - The SQLite read tolerates legacy NULL rows (the column was added after
  //   accounts already existed) via [accountDetailsFromSqlite], so a fresh cast
  //   never throws on `details_json IS NULL`.
  @Supabase(
    name: 'details',
    fromGenerator: 'accountDetailsFromSupabase(%DATA_PROPERTY%)',
    toGenerator: 'accountDetailsToSupabase(%INSTANCE_PROPERTY%)',
  )
  @Sqlite(fromGenerator: 'accountDetailsFromSqlite(%DATA_PROPERTY%)')
  final String detailsJson;

  // --- Goal fields (merged from the old `goals` table) ---------------------
  // Only meaningful when `type == 'goal'`. The `goalTargetAmount` shares the
  // account's `currency`, so a single column is enough.
  @Sqlite(name: 'goal_target_amount')
  @Supabase(
    name: 'goal_target_amount',
    fromGenerator:
        'data[\'goal_target_amount\'] == null ? null : data[\'goal_target_amount\'].toString()',
  )
  final String? goalTargetAmount;

  @Sqlite(name: 'goal_target_date')
  @Supabase(name: 'goal_target_date')
  final DateTime? goalTargetDate;

  // Tolerates legacy NULL rows: `goal_priority` was added after accounts
  // already existed, and non-goal accounts never set it. A null coalesces to
  // the default instead of throwing on the non-null cast.
  @Sqlite(
    name: 'goal_priority',
    fromGenerator: 'goalPriorityFromColumn(%DATA_PROPERTY%)',
  )
  @Supabase(
    name: 'goal_priority',
    fromGenerator: 'goalPriorityFromColumn(%DATA_PROPERTY%)',
  )
  final String goalPriority;

  // `updatedAt` is set to `now()` whenever a row is upserted.
  // `deletedAt` is the soft-delete tombstone; non-null rows are filtered out
  // of domain reads. `version` is bumped on every write to support LWW
  // conflict resolution on important records.
  @Sqlite(name: 'updated_at')
  @Supabase(name: 'updated_at')
  final DateTime updatedAt;

  @Sqlite(name: 'deleted_at', index: true)
  @Supabase(name: 'deleted_at')
  final DateTime? deletedAt;

  @Sqlite(name: 'version')
  @Supabase(name: 'version', defaultValue: '1')
  final int version;
}

/// Decodes the Supabase `details` jsonb column into the local JSON string.
String accountDetailsFromSupabase(Object? raw) {
  if (raw == null) return '{}';
  if (raw is String) return raw.isEmpty ? '{}' : raw;
  if (raw is Map) return jsonEncode(raw);
  return '{}';
}

/// Encodes the local JSON string back into a Map for the Supabase jsonb column.
Object accountDetailsToSupabase(String detailsJson) {
  if (detailsJson.isEmpty) return <String, dynamic>{};
  try {
    final decoded = jsonDecode(detailsJson);
    if (decoded is Map<String, dynamic>) return decoded;
  } catch (_) {}
  return <String, dynamic>{};
}

/// Reads the local `details_json` column, tolerating legacy NULL rows.
String accountDetailsFromSqlite(Object? raw) => raw is String ? raw : '{}';

/// Reads `goal_priority`, defaulting legacy/non-goal NULL rows to 'medium'.
String goalPriorityFromColumn(Object? raw) => raw is String ? raw : 'medium';
