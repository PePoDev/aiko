import 'dart:convert';

import 'record_codec.dart';

class OfflineAccount implements OfflineRecord {
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

  @override
  final String id;

  final String userId;

  final String name;
  final String type;
  final String currency;

  final String currentBalance;

  final String? institution;
  final bool includeInNetWorth;
  final bool isActive;

  /// The account details as a JSON string; stored as the `details` map in
  /// the row ([accountDetailsFromRow] / [accountDetailsToRow]).
  final String detailsJson;

  // --- Goal fields (merged from the old `goals` table) ---------------------
  // Only meaningful when `type == 'goal'`. The `goalTargetAmount` shares the
  // account's `currency`, so a single field is enough.
  final String? goalTargetAmount;

  final DateTime? goalTargetDate;

  final String goalPriority;

  // `updatedAt` is set to `now()` whenever a record is built for a write.
  // `version` is kept for documents written by older clients.
  final DateTime updatedAt;

  final int version;

  @override
  String? get ownerId => userId;
}

/// Decodes the row's `details` map into the record's JSON string.
String accountDetailsFromRow(Object? raw) {
  if (raw == null) return '{}';
  if (raw is String) return raw.isEmpty ? '{}' : raw;
  if (raw is Map) return jsonEncode(raw);
  return '{}';
}

/// Encodes the record's JSON string back into the row's `details` map.
Map<String, dynamic> accountDetailsToRow(String detailsJson) {
  if (detailsJson.isEmpty) return <String, dynamic>{};
  try {
    final decoded = jsonDecode(detailsJson);
    if (decoded is Map<String, dynamic>) return decoded;
  } catch (_) {}
  return <String, dynamic>{};
}

/// Reads `goal_priority`, defaulting missing (non-goal) values to 'medium'.
String goalPriorityFromColumn(Object? raw) => raw is String ? raw : 'medium';

class AccountCodec extends RecordCodec<OfflineAccount> {
  const AccountCodec();

  @override
  String get collection => 'accounts';

  @override
  OfflineAccount fromRow(Map<String, dynamic> row) => OfflineAccount(
    id: row['id'] as String,
    userId: row['user_id'] as String,
    name: row['name'] as String,
    type: row['type'] as String,
    currency: row['currency'] as String,
    currentBalance: row['current_balance'].toString(),
    institution: row['institution'] as String?,
    includeInNetWorth: row['include_in_net_worth'] as bool,
    isActive: row['is_active'] as bool,
    detailsJson: accountDetailsFromRow(row['details']),
    goalTargetAmount: row['goal_target_amount']?.toString(),
    goalTargetDate: dateFromRow(row['goal_target_date']),
    goalPriority: goalPriorityFromColumn(row['goal_priority']),
    updatedAt: dateFromRow(row['updated_at']),
    version: row['version'] as int? ?? 1,
  );

  @override
  Map<String, dynamic> toRow(OfflineAccount record) => {
    'id': record.id,
    'user_id': record.userId,
    'name': record.name,
    'type': record.type,
    'currency': record.currency,
    'current_balance': record.currentBalance,
    'institution': record.institution,
    'include_in_net_worth': record.includeInNetWorth,
    'is_active': record.isActive,
    'details': accountDetailsToRow(record.detailsJson),
    'goal_target_amount': record.goalTargetAmount,
    'goal_target_date': record.goalTargetDate?.toIso8601String(),
    'goal_priority': record.goalPriority,
    'updated_at': record.updatedAt.toIso8601String(),
    'version': record.version,
  };
}
