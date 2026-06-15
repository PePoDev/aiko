import '../../../core/money/money.dart';

enum TransactionType {
  income,
  expense,
  transfer,

  /// Outbound leg of a transfer — money leaving the source account. Paired
  /// with a [transferIn] row on the destination account.
  transferOut,

  /// Inbound leg of a transfer — money arriving in the destination account.
  /// Treated like income for balance math. Paired with a [transferOut] row.
  transferIn,
  refund,
  investmentBuy,
  investmentSell,
  dividend,
  interest,
  loanPayment,
  creditCardPayment,
  taxPayment,
  fee,
  adjustment,
}

enum TransactionStatus { draft, posted, voided, archived }

/// How often a transaction should be repeated.
///
/// The chosen frequency drives which settings panel is shown on the add-
/// transaction screen; each cadence exposes its own knobs (see
/// [RecurringSettings] for the per-frequency payload).
enum RecurringFrequency { once, daily, weekly, monthly, annually }

/// Per-frequency configuration for a recurring transaction.
///
/// Only the fields relevant to the active [RecurringFrequency] are
/// populated; everything else is null. The form validates that the right
/// combination is set for the chosen cadence.
class RecurringSettings {
  const RecurringSettings({
    this.endDate,
    this.maxOccurrences,
    this.dayOfWeek,
    this.dayOfMonth,
    this.monthOfYear,
  });

  /// Inclusive date the series stops. null = open-ended (until cancelled).
  final DateTime? endDate;

  /// Cap on the number of generated occurrences. null = no cap.
  final int? maxOccurrences;

  /// Weekly anchor. 1 = Monday … 7 = Sunday (ISO-8601).
  final int? dayOfWeek;

  /// Monthly anchor. 1–31. Days beyond the month's last day clamp to the
  /// month's actual length.
  final int? dayOfMonth;

  /// Annual anchor. 1–12.
  final int? monthOfYear;

  static const RecurringSettings empty = RecurringSettings();

  bool get isEmpty =>
      endDate == null &&
      maxOccurrences == null &&
      dayOfWeek == null &&
      dayOfMonth == null &&
      monthOfYear == null;
}

class FinanceTransaction {
  const FinanceTransaction({
    required this.id,
    required this.userId,
    required this.accountId,
    required this.type,
    required this.amount,
    required this.date,
    this.categoryId,
    this.merchant,
    this.note,
    this.tags = const [],
    this.splits = const [],
    this.status = TransactionStatus.posted,
    this.isRecurring = false,
    this.recurringFrequency,
    this.recurringSettings,
  }) : assert(
         !isRecurring || recurringFrequency != null,
         'A recurring transaction must declare a frequency.',
       );

  final String id;
  final String userId;
  final String accountId;
  final TransactionType type;
  final Money amount;
  final DateTime date;
  final String? categoryId;
  final String? merchant;
  final String? note;
  final List<String> tags;
  final List<TransactionSplit> splits;
  final TransactionStatus status;

  /// True when this transaction is part of a recurring series.
  final bool isRecurring;

  /// How often the transaction repeats. Always set when [isRecurring] is
  /// true; null otherwise.
  final RecurringFrequency? recurringFrequency;

  /// Cadence-specific knobs (end date, day of week, day of month, etc.).
  /// Always set when [isRecurring] is true; null otherwise.
  final RecurringSettings? recurringSettings;

  bool get isExpense => type == TransactionType.expense;

  /// Whether this transaction adds to (rather than subtracts from) its
  /// account balance: income and the inbound leg of a transfer.
  bool get _isInflow =>
      type == TransactionType.income || type == TransactionType.transferIn;

  Money applyToAccountBalance(Money balance) {
    return _isInflow ? balance + amount : balance - amount;
  }

  Money reverseFromAccountBalance(Money balance) {
    return _isInflow ? balance - amount : balance + amount;
  }

  FinanceTransaction copyWith({
    Money? amount,
    String? categoryId,
    String? merchant,
    List<String>? tags,
    List<TransactionSplit>? splits,
    TransactionStatus? status,
    bool? isRecurring,
    RecurringFrequency? recurringFrequency,
    RecurringSettings? recurringSettings,
  }) {
    return FinanceTransaction(
      id: id,
      userId: userId,
      accountId: accountId,
      type: type,
      amount: amount ?? this.amount,
      date: date,
      categoryId: categoryId ?? this.categoryId,
      merchant: merchant ?? this.merchant,
      note: note,
      tags: tags ?? this.tags,
      splits: splits ?? this.splits,
      status: status ?? this.status,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringFrequency: recurringFrequency ?? this.recurringFrequency,
      recurringSettings: recurringSettings ?? this.recurringSettings,
    );
  }
}

class TransactionSplit {
  const TransactionSplit({
    required this.categoryId,
    required this.amount,
    this.note,
  });

  final String categoryId;
  final Money amount;
  final String? note;
}
