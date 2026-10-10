import '../domain/transaction.dart';

class TransactionMonth implements Comparable<TransactionMonth> {
  const TransactionMonth(this.year, this.month)
    : assert(month >= 1 && month <= 12, 'month must be between 1 and 12');

  factory TransactionMonth.fromDate(DateTime date) {
    return TransactionMonth(date.year, date.month);
  }

  final int year;
  final int month;

  TransactionMonth addMonths(int offset) {
    final date = DateTime(year, month + offset);
    return TransactionMonth(date.year, date.month);
  }

  @override
  int compareTo(TransactionMonth other) {
    final yearComparison = year.compareTo(other.year);
    return yearComparison != 0 ? yearComparison : month.compareTo(other.month);
  }

  @override
  bool operator ==(Object other) {
    return other is TransactionMonth &&
        other.year == year &&
        other.month == month;
  }

  @override
  int get hashCode => Object.hash(year, month);

  /// `YYYY-MM`, the form used in route queries (`/reports/monthly?month=`).
  String get queryValue =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';

  /// Parses [queryValue]'s `YYYY-MM`; null when missing or malformed.
  static TransactionMonth? tryParseQuery(String? value) {
    final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(value?.trim() ?? '');
    if (match == null) return null;
    final month = int.parse(match[2]!);
    if (month < 1 || month > 12) return null;
    return TransactionMonth(int.parse(match[1]!), month);
  }
}

class TransactionMonthRangeService {
  const TransactionMonthRangeService();

  List<TransactionMonth> monthsFor({
    required Iterable<FinanceTransaction> transactions,
    required DateTime currentDate,
  }) {
    final currentMonth = TransactionMonth.fromDate(currentDate);
    var firstMonth = currentMonth;
    var lastMonth = currentMonth.addMonths(12);

    for (final transaction in transactions) {
      final transactionMonth = TransactionMonth.fromDate(transaction.date);
      if (transactionMonth.compareTo(firstMonth) < 0) {
        firstMonth = transactionMonth;
      }
      if (transactionMonth.compareTo(lastMonth) > 0) {
        lastMonth = transactionMonth;
      }
    }

    return [
      for (
        var month = firstMonth;
        month.compareTo(lastMonth) <= 0;
        month = month.addMonths(1)
      )
        month,
    ];
  }
}
