import 'package:csv/csv.dart';

import '../../transactions/domain/transaction.dart';

class ExportService {
  const ExportService();

  String transactionsCsv(List<FinanceTransaction> transactions) {
    final rows = [
      [
        'date',
        'type',
        'amount',
        'currency',
        'account',
        'category',
        'merchant',
        'note',
      ],
      for (final transaction in transactions)
        [
          transaction.date.toIso8601String(),
          transaction.type.name,
          transaction.amount.amount.toString(),
          transaction.amount.currency,
          transaction.accountId,
          transaction.categoryId ?? '',
          transaction.merchant ?? '',
          transaction.note ?? '',
        ],
    ];
    return csv.encode(rows);
  }
}
