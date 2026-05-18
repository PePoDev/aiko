import '../../../core/money/money.dart';
import '../../transactions/domain/transaction.dart';
import '../domain/report.dart';

class ReportService {
  const ReportService();

  Report monthly({
    required String userId,
    required DateTime periodStart,
    required DateTime periodEnd,
    required List<FinanceTransaction> transactions,
  }) {
    final spending = transactions
        .where((item) => item.type == TransactionType.expense)
        .fold(Money.zero('USD'), (total, item) => total + item.amount);
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
