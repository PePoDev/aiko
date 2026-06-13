import '../../../core/money/money.dart';
import '../domain/transaction.dart';

class TransactionDto {
  const TransactionDto(this.json);

  final Map<String, dynamic> json;

  FinanceTransaction toDomain() {
    final isRecurring = json['is_recurring'] as bool? ?? false;
    final frequencyName = json['recurring_frequency'] as String?;
    return FinanceTransaction(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      accountId: json['account_id'] as String,
      type: TransactionType.values.byName(json['type'] as String? ?? 'expense'),
      amount: Money.parse(
        '${json['amount'] ?? 0}',
        json['currency'] as String? ?? 'THB',
      ),
      date: DateTime.parse(json['date'] as String),
      categoryId: json['category_id'] as String?,
      merchant: json['merchant'] as String?,
      note: json['note'] as String?,
      tags: _tagsFromJson(json['tags']),
      isRecurring: isRecurring,
      recurringFrequency: isRecurring && frequencyName != null
          ? _frequencyFromName(frequencyName)
          : null,
      recurringSettings: isRecurring
          ? RecurringSettings(
              endDate: _parseDate(json['recurring_end_date']),
              maxOccurrences: json['recurring_max_occurrences'] as int?,
              dayOfWeek: json['recurring_day_of_week'] as int?,
              dayOfMonth: json['recurring_day_of_month'] as int?,
              monthOfYear: json['recurring_month_of_year'] as int?,
            )
          : null,
    );
  }

  static RecurringFrequency _frequencyFromName(String name) {
    for (final frequency in RecurringFrequency.values) {
      if (frequency.name == name) {
        return frequency;
      }
    }
    return RecurringFrequency.once;
  }

  static DateTime? _parseDate(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  List<String> _tagsFromJson(Object? value) {
    if (value == null) {
      return const [];
    }
    if (value is List) {
      return value.map((tag) => tag.toString()).toList(growable: false);
    }
    if (value is String) {
      return value
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList(growable: false);
    }
    return const [];
  }
}
