import 'package:brick_offline_first_with_supabase/brick_offline_first_with_supabase.dart';
import 'package:brick_sqlite/brick_sqlite.dart';
import 'package:brick_supabase/brick_supabase.dart';

@ConnectOfflineFirstWithSupabase(
  supabaseConfig: SupabaseSerializable(tableName: 'transactions'),
)
class OfflineTransaction extends OfflineFirstWithSupabaseModel {
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
    DateTime? updatedAt,
    this.version = 1,
  }) : updatedAt = updatedAt ?? DateTime.now().toUtc();

  @Sqlite(unique: true)
  @Supabase(unique: true)
  final String id;

  @Sqlite(index: true)
  final String userId;

  @Sqlite(index: true)
  final String accountId;

  final String type;

  @Supabase(fromGenerator: 'data[\'amount\'].toString()')
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

  @Sqlite(name: 'updated_at')
  @Supabase(name: 'updated_at')
  final DateTime updatedAt;

  @Sqlite(name: 'version')
  @Supabase(name: 'version', defaultValue: '1')
  final int version;
}
