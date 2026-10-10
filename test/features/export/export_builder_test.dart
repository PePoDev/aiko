import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/export/application/export_builder.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:aiko/l10n/app_localizations.dart';
import 'package:csv/csv.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

FinanceTransaction _tx(
  TransactionType type,
  String amount, {
  String currency = 'THB',
  String? merchant,
  String? note,
  String accountId = 'acc-1',
}) => FinanceTransaction(
  id: '${type.name}-$amount',
  userId: 'u',
  accountId: accountId,
  type: type,
  amount: Money.parse(amount, currency),
  date: DateTime(2026, 10, 3, 9, 30),
  merchant: merchant,
  note: note,
);

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  setUpAll(() => initializeDateFormatting('en'));

  group('signedAmount', () {
    test('inflow types are positive, everything else negative', () {
      for (final type in [
        TransactionType.income,
        TransactionType.transferIn,
        TransactionType.refund,
        TransactionType.dividend,
        TransactionType.interest,
        TransactionType.investmentSell,
      ]) {
        expect(
          signedAmount(_tx(type, '10')),
          Decimal.fromInt(10),
          reason: '$type',
        );
      }
      for (final type in [
        TransactionType.expense,
        TransactionType.transferOut,
        TransactionType.investmentBuy,
        TransactionType.fee,
        TransactionType.loanPayment,
      ]) {
        expect(
          signedAmount(_tx(type, '10')),
          Decimal.fromInt(-10),
          reason: '$type',
        );
      }
    });
  });

  group('escapeSpreadsheetCell', () {
    test('prefixes formula triggers with an apostrophe', () {
      expect(escapeSpreadsheetCell('=HYPERLINK("x")'), "'=HYPERLINK(\"x\")");
      expect(escapeSpreadsheetCell('+1'), "'+1");
      expect(escapeSpreadsheetCell('-2+3'), "'-2+3");
      expect(escapeSpreadsheetCell('@SUM(A1)'), "'@SUM(A1)");
      expect(escapeSpreadsheetCell('\tcmd'), "'\tcmd");
      expect(escapeSpreadsheetCell('\rcmd'), "'\rcmd");
    });

    test('leaves ordinary text alone', () {
      expect(escapeSpreadsheetCell(''), '');
      expect(escapeSpreadsheetCell('Coffee = good'), 'Coffee = good');
      expect(escapeSpreadsheetCell('ร้านกาแฟ'), 'ร้านกาแฟ');
    });
  });

  group('buildExportCsvRows', () {
    test('adds account and currency columns, signs and escapes', () {
      final rows = buildExportCsvRows(
        transactions: [
          _tx(TransactionType.expense, '120.50', merchant: '=cmd()'),
          _tx(
            TransactionType.refund,
            '20',
            currency: 'USD',
            note: '@note',
            accountId: 'acc-2',
          ),
        ],
        l10n: l10n,
        categoryName: (_) => 'Food',
        accountName: (tx) => tx.accountId == 'acc-1' ? 'Wallet' : '-Card',
      );

      expect(rows.first, [
        'Date',
        'Merchant',
        'Category',
        'Account',
        'Type',
        'Amount',
        'Currency',
        'Note',
      ]);
      expect(rows[1], [
        '2026-10-03 09:30',
        "'=cmd()",
        'Food',
        'Wallet',
        'Expense',
        '-120.5',
        'THB',
        '',
      ]);
      expect(rows[2][3], "'-Card");
      expect(rows[2][5], '20');
      expect(rows[2][6], 'USD');
      expect(rows[2][7], "'@note");
      // The escaped cell survives CSV encoding.
      expect(csv.encode(rows), contains("'=cmd()"));
    });
  });

  group('buildStatementHtml', () {
    test('signs by direction and keeps each amount in its currency', () {
      final html = buildStatementHtml(
        transactions: [
          _tx(TransactionType.income, '1000'),
          _tx(TransactionType.expense, '250'),
          _tx(TransactionType.refund, '15', currency: 'USD'),
          _tx(TransactionType.transferIn, '40'),
          _tx(TransactionType.expense, '5', currency: 'USD', merchant: '<b>'),
        ],
        l10n: l10n,
        categoryName: (_) => 'Food',
        baseCurrency: 'THB',
        generatedAt: DateTime(2026, 10, 10, 8),
      );

      final amountCells = RegExp(
        r'<td class="(amount-income|amount-expense)">([^<]*)</td>',
      ).allMatches(html).map((m) => '${m[1]}|${m[2]}').toList();
      expect(amountCells, [
        'amount-income|+ ฿1,000.00',
        'amount-expense|− ฿250.00',
        'amount-income|+ \$15.00',
        'amount-income|+ ฿40.00',
        'amount-expense|− \$5.00',
      ]);
      // Totals per currency: THB income 1,000 / expense 250, USD expense 5.
      expect(html, contains('฿1,000.00<br>\$0.00'));
      expect(html, contains('฿250.00<br>\$5.00'));
      expect(html, contains('฿750.00<br>-\$5.00'));
      expect(html, contains('&lt;b&gt;'));
      expect(html, isNot(contains('<b>')));
    });
  });
}
