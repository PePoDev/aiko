import '../../../core/money/money.dart';
import '../../../core/money/currency_conversion_service.dart';
import '../../transactions/domain/transaction.dart';
import '../domain/report.dart';

class ReportService {
  const ReportService();

  Report monthly({
    required String userId,
    required DateTime periodStart,
    required DateTime periodEnd,
    required List<FinanceTransaction> transactions,
    String baseCurrency = 'USD',
    CurrencyConversionService? converter,
  }) {
    final spending = transactions
        .where((item) => item.type == TransactionType.expense)
        .map((item) {
          if (item.amount.currency == baseCurrency) {
            return item.amount;
          }
          return converter?.convert(item.amount, baseCurrency);
        })
        .whereType<Money>()
        .fold(Money.zero(baseCurrency), (total, item) => total + item);
    return Report(
      id: 'monthly-${periodStart.month}',
      userId: userId,
      type: 'monthly',
      periodStart: periodStart,
      periodEnd: periodEnd,
      summary: {
        'spending': spending.amount.toString(),
        'currency': spending.currency,
        'action_items': ['Review dining', 'Fund emergency savings'],
      },
    );
  }
}
