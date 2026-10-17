import 'record_codec.dart';

class OfflineTransaction implements OfflineRecord {
  OfflineTransaction({
    required this.id,
    required this.userId,
    required this.accountId,
    required this.type,
    required this.amount,
    required this.currency,
    required this.date,
    this.categoryId,
    this.merchant,
    this.note,
    this.tags = const [],
    this.status = 'posted',
    this.isRecurring = false,
    this.recurringFrequency,
    this.recurringEndDate,
    this.recurringMaxOccurrences,
    this.recurringDayOfWeek,
    this.recurringDayOfMonth,
    this.recurringMonthOfYear,
    this.reminderAt,
    this.transferGroupId,
    DateTime? updatedAt,
    this.version = 1,
  }) : updatedAt = updatedAt ?? DateTime.now().toUtc();

  @override
  final String id;

  final String userId;

  final String accountId;

  final String type;

  final String amount;

  final String currency;

  final DateTime date;

  final String? categoryId;
  final String? merchant;
  final String? note;
  final List<String> tags;
  final String status;

  /// True when the row is part of a recurring series.
  final bool isRecurring;

  /// One of: once, daily, weekly, monthly, annually. null when
  /// [isRecurring] is false.
  final String? recurringFrequency;

  /// Inclusive date the series stops. null = open-ended.
  final DateTime? recurringEndDate;

  /// Cap on the number of generated occurrences. null = no cap.
  final int? recurringMaxOccurrences;

  /// Weekly anchor (1 = Monday … 7 = Sunday). Weekly series only.
  final int? recurringDayOfWeek;

  /// Monthly anchor (1–31). Monthly series only.
  final int? recurringDayOfMonth;

  /// Annual anchor (1–12). Annually series only.
  final int? recurringMonthOfYear;

  /// Local time to fire a reminder notification. null = no reminder.
  final DateTime? reminderAt;

  /// Links the two legs of one transfer. null on other rows and legacy legs.
  final String? transferGroupId;

  final DateTime updatedAt;

  final int version;

  @override
  String? get ownerId => userId;
}

class TransactionCodec extends RecordCodec<OfflineTransaction> {
  const TransactionCodec();

  @override
  String get collection => 'transactions';

  @override
  OfflineTransaction fromRow(Map<String, dynamic> row) => OfflineTransaction(
    id: row['id'] as String,
    userId: row['user_id'] as String,
    accountId: row['account_id'] as String,
    type: row['type'] as String,
    amount: row['amount'].toString(),
    currency: row['currency'] as String,
    date: DateTime.parse(row['date'] as String),
    categoryId: row['category_id'] as String?,
    merchant: row['merchant'] as String?,
    note: row['note'] as String?,
    tags: List<String>.from(row['tags'] as List),
    status: row['status'] as String,
    isRecurring: row['is_recurring'] as bool,
    recurringFrequency: row['recurring_frequency'] as String?,
    recurringEndDate: dateFromRow(row['recurring_end_date']),
    recurringMaxOccurrences: row['recurring_max_occurrences'] as int?,
    recurringDayOfWeek: row['recurring_day_of_week'] as int?,
    recurringDayOfMonth: row['recurring_day_of_month'] as int?,
    recurringMonthOfYear: row['recurring_month_of_year'] as int?,
    reminderAt: dateFromRow(row['reminder_at']),
    transferGroupId: row['transfer_group_id'] as String?,
    updatedAt: dateFromRow(row['updated_at']),
    version: row['version'] as int? ?? 1,
  );

  @override
  Map<String, dynamic> toRow(OfflineTransaction record) => {
    'id': record.id,
    'user_id': record.userId,
    'account_id': record.accountId,
    'type': record.type,
    'amount': record.amount,
    'currency': record.currency,
    'date': record.date.toIso8601String(),
    'category_id': record.categoryId,
    'merchant': record.merchant,
    'note': record.note,
    'tags': record.tags,
    'status': record.status,
    'is_recurring': record.isRecurring,
    'recurring_frequency': record.recurringFrequency,
    'recurring_end_date': record.recurringEndDate?.toIso8601String(),
    'recurring_max_occurrences': record.recurringMaxOccurrences,
    'recurring_day_of_week': record.recurringDayOfWeek,
    'recurring_day_of_month': record.recurringDayOfMonth,
    'recurring_month_of_year': record.recurringMonthOfYear,
    'reminder_at': record.reminderAt?.toIso8601String(),
    'transfer_group_id': record.transferGroupId,
    'updated_at': record.updatedAt.toIso8601String(),
    'version': record.version,
  };
}
