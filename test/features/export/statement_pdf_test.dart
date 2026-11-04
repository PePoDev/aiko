import 'dart:io';
import 'dart:typed_data';

import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/export/application/statement_pdf.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:aiko/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

ByteData _font(String path) =>
    ByteData.sublistView(File('assets/fonts/$path').readAsBytesSync());

void main() {
  setUpAll(initializeDateFormatting);

  final fonts = StatementFonts(
    regular: _font('manrope/Manrope-Regular.ttf'),
    bold: _font('manrope/Manrope-Bold.ttf'),
    thai: _font('noto_sans_thai/NotoSansThai-Regular.ttf'),
    thaiBold: _font('noto_sans_thai/NotoSansThai-Bold.ttf'),
  );

  FinanceTransaction tx(
    String id,
    TransactionType type,
    String amount,
    String merchant,
  ) => FinanceTransaction(
    id: id,
    userId: 'u',
    accountId: 'a',
    type: type,
    amount: Money.parse(amount, 'THB'),
    date: DateTime(2026, 10, 19, 9),
    merchant: merchant,
  );

  for (final language in ['en', 'th']) {
    test('a $language statement is a PDF with every transaction', () async {
      final transactions = [
        tx('1', TransactionType.income, '50000', 'เงินเดือน Salary'),
        for (var i = 0; i < 80; i++)
          tx(
            'e$i',
            TransactionType.expense,
            '${65 + i}',
            'กาแฟ ร้านสตาร์บัคส์ $i',
          ),
      ];
      final bytes = await buildStatementPdf(
        transactions: transactions,
        l10n: lookupAppLocalizations(Locale(language)),
        categoryName: (_) => 'อาหารและเครื่องดื่ม',
        baseCurrency: 'THB',
        generatedAt: DateTime(2026, 10, 19, 10),
        fonts: fonts,
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      // 81 rows don't fit one A4 page.
      expect(
        RegExp(
          '/Type */Page[^s]',
        ).allMatches(String.fromCharCodes(bytes)).length,
        greaterThan(1),
      );
      // AIKO_PDF_OUT=<dir> keeps the files to look at.
      final out = Platform.environment['AIKO_PDF_OUT'];
      if (out != null) {
        File('$out/statement_$language.pdf').writeAsBytesSync(bytes);
      }
    });
  }
}
