import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/export/application/export_service.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CSV export includes date, amount, currency, and merchant', () {
    final csv = const ExportService().transactionsCsv([
      FinanceTransaction(
        id: 't1',
        userId: 'user',
        accountId: 'cash',
        type: TransactionType.expense,
        amount: Money.parse('4.50', 'USD'),
        date: DateTime(2026, 1, 2),
        merchant: 'Coffee',
      ),
    ]);

    expect(csv, contains('merchant'));
    expect(csv, contains('Coffee'));
    expect(csv, contains('USD'));
  });
}
