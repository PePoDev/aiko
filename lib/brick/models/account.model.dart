import 'dart:convert';

import 'package:brick_sqlite/brick_sqlite.dart';

class OfflineAccount extends SqliteModel {
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
    this.version = 1,
  }) : updatedAt = updatedAt ?? DateTime.now().toUtc();

  @Sqlite(unique: true)
  final String id;

  @Sqlite(index: true)
  final String userId;

  final String name;
  final String type;
  final String currency;

  final String currentBalance;

  final String? institution;
  final bool includeInNetWorth;
  final bool isActive;

  // Stored locally as a JSON string but as a `document map` (Map) column named
  // `details` in Firestore. The generators below keep the conversion regen-safe:
  // - Firestore read/write goes through [accountDetailsFromFirestore] /
  //   [accountDetailsToFirestore] so the document map Map round-trips to/from a String.
  // - The SQLite read tolerates legacy NULL rows (the column was added after
  //   accounts already existed) via [accountDetailsFromSqlite], so a fresh cast
  //   never throws on `details_json IS NULL`.
  @Sqlite(fromGenerator: 'accountDetailsFromSqlite(%DATA_PROPERTY%)')
  final String detailsJson;

  // --- Goal fields (merged from the old `goals` table) ---------------------
  // Only meaningful when `type == 'goal'`. The `goalTargetAmount` shares the
  // account's `currency`, so a single column is enough.
  @Sqlite(name: 'goal_target_amount')
  final String? goalTargetAmount;

  @Sqlite(name: 'goal_target_date')
  final DateTime? goalTargetDate;

  // Tolerates legacy NULL rows: `goal_priority` was added after accounts
  // already existed, and non-goal accounts never set it. A null coalesces to
  // the default instead of throwing on the non-null cast.
  @Sqlite(
    name: 'goal_priority',
    fromGenerator: 'goalPriorityFromColumn(%DATA_PROPERTY%)',
  )
  final String goalPriority;

  // `updatedAt` is set to `now()` whenever a row is upserted. `version` is
  // bumped on every write to support LWW conflict resolution on important
  // records.
  @Sqlite(name: 'updated_at')
  final DateTime updatedAt;

  @Sqlite(name: 'version')
  final int version;
}

/// Decodes the Firestore `details` document map column into the local JSON string.
String accountDetailsFromFirestore(Object? raw) {
  if (raw == null) return '{}';
  if (raw is String) return raw.isEmpty ? '{}' : raw;
  if (raw is Map) return jsonEncode(raw);
  return '{}';
}

/// Encodes the local JSON string back into a Map for the Firestore document map column.
Object accountDetailsToFirestore(String detailsJson) {
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
