import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/export/application/export_service.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

FinanceTransaction _tx({
  String id = 'tx-1',
  TransactionType type = TransactionType.expense,
  String amount = '12.50',
  String currency = 'THB',
  String accountId = 'acc-1',
  String? categoryId,
  String? merchant,
  String? note,
  DateTime? date,
}) {
  return FinanceTransaction(
    id: id,
    userId: 'user-1',
    accountId: accountId,
    type: type,
    amount: Money(amount: Decimal.parse(amount), currency: currency),
    date: date ?? DateTime(2026, 5, 24, 9, 30),
    categoryId: categoryId,
    merchant: merchant,
    note: note,
  );
}

void main() {
  const service = ExportService();

  group('transactionsCsv', () {
    test('emits a header row even when there are no transactions', () {
      final csv = service.transactionsCsv(const []);
      final lines = csv.trim().split('\r\n');

      expect(lines, hasLength(1));
      expect(
        lines.first,
        'date,type,amount,currency,account,category,merchant,note',
      );
    });

    test('writes one data row per transaction in order', () {
      final csv = service.transactionsCsv([
        _tx(id: 'a', merchant: 'Coffee'),
        _tx(id: 'b', merchant: 'Lunch'),
      ]);
      final lines = csv.trim().split('\r\n');

      expect(lines, hasLength(3));
      expect(lines[1], contains('Coffee'));
      expect(lines[2], contains('Lunch'));
    });

    test('serializes the core transaction fields', () {
      final csv = service.transactionsCsv([
        _tx(
          type: TransactionType.income,
          amount: '99.99',
          currency: 'USD',
          accountId: 'acc-42',
          categoryId: 'cat-7',
          merchant: 'Acme',
          date: DateTime(2026, 1, 2, 3, 4),
        ),
      ]);
      final row = csv.trim().split('\r\n')[1];

      expect(row, contains('2026-01-02T03:04:00.000'));
      expect(row, contains('income'));
      expect(row, contains('99.99'));
      expect(row, contains('USD'));
      expect(row, contains('acc-42'));
      expect(row, contains('cat-7'));
      expect(row, contains('Acme'));
    });

    test('renders null category/merchant/note as empty fields', () {
      final csv = service.transactionsCsv([
        _tx(merchant: null, note: null, categoryId: null),
      ]);
      final row = csv.trim().split('\r\n')[1];

      // Trailing empty fields for category, merchant and note.
      expect(row, endsWith(',,,'));
    });

    test('quotes fields containing commas so columns stay aligned', () {
      final csv = service.transactionsCsv([
        _tx(merchant: 'Shop, Inc.', note: 'lunch, tip'),
      ]);
      final row = csv.trim().split('\r\n')[1];

      expect(row, contains('"Shop, Inc."'));
      expect(row, contains('"lunch, tip"'));
    });
  });

  group('transactionsExcelCsv', () {
    test('prefixes a UTF-8 BOM so Excel detects the encoding', () {
      final excel = service.transactionsExcelCsv([_tx()]);

      expect(excel.codeUnitAt(0), 0xFEFF);
      expect(excel.substring(1), service.transactionsCsv([_tx()]));
    });
  });

  group('statementHtml', () {
    test('embeds the provided title', () {
      final html = service.statementHtml(
        title: 'May Statement',
        transactions: const [],
      );

      expect(html, contains('<title>May Statement</title>'));
      expect(html, contains('<h1>May Statement</h1>'));
    });

    test('renders a table row per transaction with a date-only column', () {
      final html = service.statementHtml(
        title: 'Statement',
        transactions: [
          _tx(merchant: 'Coffee', date: DateTime(2026, 5, 24, 9, 30)),
        ],
      );

      expect(html, contains('<td>2026-05-24</td>'));
      expect(html, isNot(contains('2026-05-24T09:30')));
      expect(html, contains('Coffee'));
      expect(html, contains('expense'));
    });

    test('produces an empty tbody when there are no transactions', () {
      final html = service.statementHtml(
        title: 'Empty',
        transactions: const [],
      );

      expect(html, contains('<tbody></tbody>'));
    });
  });
}
