import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/reports/application/report_service.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('monthly report aggregates expense spending', () {
    final report = const ReportService().monthly(
      userId: 'user',
      periodStart: DateTime(2026, 1),
      periodEnd: DateTime(2026, 1, 31),
      transactions: [
        FinanceTransaction(
          id: 't1',
          userId: 'user',
          accountId: 'cash',
          type: TransactionType.expense,
          amount: Money.parse('50', 'USD'),
          date: DateTime(2026, 1, 2),
        ),
      ],
    );

    expect(report.summary['spending'], '50');
  });
}
