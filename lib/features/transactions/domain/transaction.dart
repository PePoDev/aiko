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

  /// Balance correction (an account's opening balance, or the difference when
  /// the balance is edited). Its amount is SIGNED: positive raises the
  /// balance, negative lowers it. Never income or spending.
  adjustment;

  /// Money coming into the account: income, the inbound transfer leg,
  /// refunds, dividends, interest and investment sales. Every other type
  /// (except a signed [adjustment]) takes money out.
  bool get isInflow => switch (this) {
    income ||
    transferIn ||
    refund ||
    dividend ||
    interest ||
    investmentSell => true,
    _ => false,
  };

  /// A transfer row (either leg, or a legacy single-row transfer). Transfers
  /// move money between the user's own accounts, so they are neither income
  /// nor spending.
  bool get isTransfer =>
      this == transfer || this == transferIn || this == transferOut;
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
  }) : assert(
         dayOfWeek == null || (dayOfWeek >= 1 && dayOfWeek <= 7),
         'dayOfWeek must be 1–7 (ISO-8601) or null.',
       ),
       assert(
         dayOfMonth == null || (dayOfMonth >= 1 && dayOfMonth <= 31),
         'dayOfMonth must be 1–31 or null.',
       ),
       assert(
         monthOfYear == null || (monthOfYear >= 1 && monthOfYear <= 12),
         'monthOfYear must be 1–12 or null.',
       ),
       assert(
         maxOccurrences == null || maxOccurrences > 0,
         'maxOccurrences must be positive when set.',
       );

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
    this.reminderAt,
    this.transferGroupId,
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

  /// Local wall-clock time to fire a reminder notification. null = no reminder.
  final DateTime? reminderAt;

  /// Shared by the two legs (`transferOut` + `transferIn`) of one transfer so
  /// they are edited and deleted together. null on every other row and on
  /// transfer legs saved before legs were linked.
  final String? transferGroupId;

  bool get isExpense => type == TransactionType.expense;

  /// Whether this transaction adds to (rather than subtracts from) its
  /// account balance. Adjustments carry their own sign.
  bool get isInflow =>
      type == TransactionType.adjustment ? !amount.isNegative : type.isInflow;

  /// The change this row makes to its account's balance: positive for money
  /// in, negative for money out.
  Money get signedAmount {
    if (type == TransactionType.adjustment || type.isInflow) return amount;
    return Money(amount: -amount.amount, currency: amount.currency);
  }

  /// The amount without its sign, for display next to a `+`/`-` from
  /// [isInflow].
  Money get absoluteAmount =>
      Money(amount: amount.amount.abs(), currency: amount.currency);

  // ponytail: no-FX rule — a transaction in a different currency than the
  // account leaves the balance untouched (no rate stored to convert with).
  // Add conversion here if/when transactions carry an exchange rate.
  Money applyToAccountBalance(Money balance) {
    if (amount.currency != balance.currency) return balance;
    return balance + signedAmount;
  }

  Money reverseFromAccountBalance(Money balance) {
    if (amount.currency != balance.currency) return balance;
    return balance - signedAmount;
  }

  FinanceTransaction copyWith({
    String? accountId,
    TransactionType? type,
    Money? amount,
    DateTime? date,
    String? categoryId,
    bool clearCategoryId = false,
    String? merchant,
    String? note,
    List<String>? tags,
    List<TransactionSplit>? splits,
    TransactionStatus? status,
    bool? isRecurring,
    RecurringFrequency? recurringFrequency,
    RecurringSettings? recurringSettings,
    DateTime? reminderAt,
    bool clearReminderAt = false,
    String? transferGroupId,
  }) {
    return FinanceTransaction(
      id: id,
      userId: userId,
      accountId: accountId ?? this.accountId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      merchant: merchant ?? this.merchant,
      note: note ?? this.note,
      tags: tags ?? this.tags,
      splits: splits ?? this.splits,
      status: status ?? this.status,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringFrequency: recurringFrequency ?? this.recurringFrequency,
      recurringSettings: recurringSettings ?? this.recurringSettings,
      reminderAt: clearReminderAt ? null : (reminderAt ?? this.reminderAt),
      transferGroupId: transferGroupId ?? this.transferGroupId,
    );
  }
}

/// The balance [transactions] add up to for an account in [currency],
/// starting from zero (the opening balance is itself an adjustment row).
Money balanceFromTransactions(
  Iterable<FinanceTransaction> transactions,
  String currency,
) {
  var balance = Money.zero(currency);
  for (final transaction in transactions) {
    balance = transaction.applyToAccountBalance(balance);
  }
  return balance;
}

/// The other leg(s) of [transaction]'s transfer: rows in [all] sharing its
/// [FinanceTransaction.transferGroupId]. Empty for unlinked rows.
List<FinanceTransaction> transferPartnersOf(
  FinanceTransaction transaction,
  Iterable<FinanceTransaction> all,
) {
  final groupId = transaction.transferGroupId;
  if (groupId == null) return const [];
  return [
    for (final other in all)
      if (other.transferGroupId == groupId && other.id != transaction.id) other,
  ];
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
