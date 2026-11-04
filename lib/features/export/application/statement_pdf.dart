import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/money/money.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/domain_labels.dart';
import '../../transactions/domain/transaction.dart';
import 'export_builder.dart';

/// The TrueType fonts a PDF statement embeds: Latin text, with Thai as the
/// fallback for characters the Latin font lacks (Thai text, the baht sign).
class StatementFonts {
  const StatementFonts({
    required this.regular,
    required this.bold,
    required this.thai,
    required this.thaiBold,
  });

  final ByteData regular;
  final ByteData bold;
  final ByteData thai;
  final ByteData thaiBold;
}

/// The statement [buildStatementHtml] prints, as a PDF file: totals per
/// currency and every transaction in its own currency, in [l10n]'s language.
Future<Uint8List> buildStatementPdf({
  required List<FinanceTransaction> transactions,
  required AppLocalizations l10n,
  required String Function(FinanceTransaction tx) categoryName,
  required String baseCurrency,
  required DateTime generatedAt,
  required StatementFonts fonts,
}) {
  final locale = l10n.localeName;
  String money(Decimal amount, String currency) =>
      Money(amount: amount, currency: currency).format(locale: locale);

  final income = <String, Decimal>{};
  final expense = <String, Decimal>{};
  for (final tx in transactions) {
    final currency = tx.amount.currency;
    if (tx.type == TransactionType.income) {
      income[currency] = (income[currency] ?? Decimal.zero) + tx.amount.amount;
    } else if (tx.type == TransactionType.expense) {
      expense[currency] =
          (expense[currency] ?? Decimal.zero) + tx.amount.amount;
    }
  }
  final currencies = {...income.keys, ...expense.keys}.toList()..sort();
  if (currencies.isEmpty) currencies.add(baseCurrency);
  String totals(Decimal Function(String currency) amountIn) => currencies
      .map((currency) => money(amountIn(currency), currency))
      .join('\n');

  const blue = PdfColor.fromInt(0xFF3B82F6);
  const green = PdfColor.fromInt(0xFF10B981);
  const red = PdfColor.fromInt(0xFFEF4444);
  const grey = PdfColor.fromInt(0xFF666666);
  const card = PdfColor.fromInt(0xFFF3F4F6);
  const stripe = PdfColor.fromInt(0xFFF9FAFB);

  pw.Widget totalCard(String title, String value, PdfColor accent) =>
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: card,
            border: pw.Border(left: pw.BorderSide(color: accent, width: 4)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 9,
                  color: grey,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );

  final rowDate = DateFormat('yyyy-MM-dd HH:mm');
  final rows = [
    for (final tx in transactions)
      [
        rowDate.format(tx.date),
        tx.merchant ?? '—',
        categoryName(tx),
        tx.type.label(l10n),
        '${isExportInflow(tx) ? '+' : '-'} '
            '${money(tx.absoluteAmount.amount, tx.amount.currency)}',
      ],
  ];

  final document = pw.Document(
    title: l10n.exportStatementTitle,
    creator: 'Aiko',
    theme: pw.ThemeData.withFont(
      base: pw.Font.ttf(fonts.regular),
      bold: pw.Font.ttf(fonts.bold),
      fontFallback: [pw.Font.ttf(fonts.thai), pw.Font.ttf(fonts.thaiBold)],
    ),
  );
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      footer: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            l10n.exportFooter,
            style: const pw.TextStyle(fontSize: 8, color: grey),
          ),
          pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: grey),
          ),
        ],
      ),
      build: (context) => [
        pw.Text(
          l10n.exportStatementTitle,
          style: pw.TextStyle(
            fontSize: 22,
            color: blue,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          l10n.exportGeneratedOn(
            DateFormat.yMMMMd(locale).add_Hm().format(generatedAt),
          ),
          style: const pw.TextStyle(fontSize: 10, color: grey),
        ),
        pw.SizedBox(height: 20),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            totalCard(
              l10n.exportTotalIncome,
              totals((c) => income[c] ?? Decimal.zero),
              green,
            ),
            pw.SizedBox(width: 12),
            totalCard(
              l10n.exportTotalExpenses,
              totals((c) => expense[c] ?? Decimal.zero),
              red,
            ),
            pw.SizedBox(width: 12),
            totalCard(
              l10n.exportNetCashFlow,
              totals(
                (c) =>
                    (income[c] ?? Decimal.zero) - (expense[c] ?? Decimal.zero),
              ),
              blue,
            ),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          l10n.exportTransactionDetails,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: [
            l10n.exportColumnDate,
            l10n.exportColumnMerchant,
            l10n.exportColumnCategory,
            l10n.exportColumnType,
            l10n.exportColumnAmount,
          ],
          data: rows,
          border: null,
          headerDecoration: const pw.BoxDecoration(color: blue),
          headerStyle: pw.TextStyle(
            color: PdfColors.white,
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
          ),
          headerAlignment: pw.Alignment.centerLeft,
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellAlignments: {4: pw.Alignment.topRight},
          oddRowDecoration: const pw.BoxDecoration(color: stripe),
          columnWidths: {
            0: const pw.FixedColumnWidth(92),
            1: const pw.FlexColumnWidth(3),
            2: const pw.FlexColumnWidth(3),
            3: const pw.FlexColumnWidth(2),
            4: const pw.FixedColumnWidth(90),
          },
          // Money in green, money out red, like the HTML statement.
          textStyleBuilder: (index, data, rowNum) => index == 4 && rowNum > 0
              ? pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: isExportInflow(transactions[rowNum - 1]) ? green : red,
                )
              : null,
        ),
      ],
    ),
  );
  return document.save();
}
