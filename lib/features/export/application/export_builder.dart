import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

import '../../../core/money/money.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/domain_labels.dart';
import '../../transactions/domain/transaction.dart';

/// Transaction types that bring money in. Every other type is money going
/// out and is exported with a minus sign.
const exportInflowTypes = {
  TransactionType.income,
  TransactionType.transferIn,
  TransactionType.refund,
  TransactionType.dividend,
  TransactionType.interest,
  TransactionType.investmentSell,
};

bool isExportInflow(FinanceTransaction tx) =>
    exportInflowTypes.contains(tx.type);

/// [tx]'s amount signed by direction: positive in, negative out.
Decimal signedAmount(FinanceTransaction tx) =>
    isExportInflow(tx) ? tx.amount.amount : -tx.amount.amount;

/// Stops a text cell from running as a spreadsheet formula: a value starting
/// with `=`, `+`, `-`, `@`, a tab or a carriage return gets a leading
/// apostrophe, so Excel and Sheets show it as plain text.
String escapeSpreadsheetCell(String value) {
  if (value.isEmpty) return value;
  const triggers = {'=', '+', '-', '@', '\t', '\r'};
  return triggers.contains(value[0]) ? "'$value" : value;
}

final _rowDate = DateFormat('yyyy-MM-dd HH:mm');

/// Header plus one row per transaction. Text cells are escaped against
/// formula injection; the signed amount stays a plain number.
List<List<String>> buildExportCsvRows({
  required List<FinanceTransaction> transactions,
  required AppLocalizations l10n,
  required String Function(FinanceTransaction tx) categoryName,
  required String Function(FinanceTransaction tx) accountName,
}) {
  return [
    [
      l10n.exportColumnDate,
      l10n.exportColumnMerchant,
      l10n.exportColumnCategory,
      l10n.exportColumnAccount,
      l10n.exportColumnType,
      l10n.exportColumnAmount,
      l10n.exportColumnCurrency,
      l10n.exportColumnNote,
    ],
    for (final tx in transactions)
      [
        _rowDate.format(tx.date),
        escapeSpreadsheetCell(tx.merchant ?? ''),
        escapeSpreadsheetCell(categoryName(tx)),
        escapeSpreadsheetCell(accountName(tx)),
        escapeSpreadsheetCell(tx.type.label(l10n)),
        signedAmount(tx).toString(),
        escapeSpreadsheetCell(tx.amount.currency),
        escapeSpreadsheetCell(tx.note ?? ''),
      ],
  ];
}

/// A printable HTML statement. Every amount is shown in its own currency;
/// the income, expense and net totals are given per currency.
String buildStatementHtml({
  required List<FinanceTransaction> transactions,
  required AppLocalizations l10n,
  required String Function(FinanceTransaction tx) categoryName,
  required String baseCurrency,
  required DateTime generatedAt,
}) {
  const htmlEscape = HtmlEscape();
  String escape(String text) => htmlEscape.convert(text);
  final locale = l10n.localeName;
  String money(Decimal amount, String currency) =>
      escape(Money(amount: amount, currency: currency).format(locale: locale));

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
      .join('<br>');
  final totalIncome = totals((c) => income[c] ?? Decimal.zero);
  final totalExpense = totals((c) => expense[c] ?? Decimal.zero);
  final totalNet = totals(
    (c) => (income[c] ?? Decimal.zero) - (expense[c] ?? Decimal.zero),
  );

  final rows = StringBuffer();
  for (final tx in transactions) {
    final inflow = isExportInflow(tx);
    rows.write('''
            <tr>
              <td>${_rowDate.format(tx.date)}</td>
              <td>${escape(tx.merchant ?? '—')}</td>
              <td>${escape(categoryName(tx))}</td>
              <td class="type-caps">${escape(tx.type.label(l10n))}</td>
              <td class="${inflow ? 'amount-income' : 'amount-expense'}">${inflow ? '+' : '−'} ${money(tx.amount.amount, tx.amount.currency)}</td>
            </tr>
''');
  }

  return '''
<!DOCTYPE html>
<html lang="${escape(locale)}">
<head>
  <meta charset="utf-8">
  <title>${escape(l10n.exportStatementTitle)}</title>
  <style>
    body { font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; color: #333; margin: 40px; line-height: 1.6; }
    h1 { color: #3B82F6; font-size: 28px; margin-bottom: 5px; }
    .subtitle { color: #666; font-size: 14px; margin-bottom: 30px; }
    .card-row { display: flex; gap: 20px; margin-bottom: 30px; }
    .card { flex: 1; padding: 20px; border-radius: 8px; background: #f3f4f6; border-left: 5px solid #3B82F6; }
    .card.income { border-left-color: #10B981; }
    .card.expense { border-left-color: #EF4444; }
    .card-title { font-size: 11px; color: #666; text-transform: uppercase; font-weight: bold; letter-spacing: 0.5px; }
    .card-value { font-size: 22px; font-weight: bold; margin-top: 5px; }
    table { width: 100%; border-collapse: collapse; margin-top: 20px; }
    th { text-align: left; padding: 12px; background: #3B82F6; color: white; font-weight: 600; font-size: 13px; }
    td { padding: 12px; border-bottom: 1px solid #e5e7eb; font-size: 13px; }
    tr:nth-child(even) { background: #f9fafb; }
    .type-caps { text-transform: uppercase; font-size: 11px; font-weight: bold; color: #666; }
    .amount-income { color: #10B981; font-weight: bold; white-space: nowrap; }
    .amount-expense { color: #EF4444; font-weight: bold; white-space: nowrap; }
    .footer { margin-top: 50px; text-align: center; font-size: 11px; color: #999; border-top: 1px solid #eee; padding-top: 20px; }
  </style>
</head>
<body>
  <h1>${escape(l10n.exportStatementTitle)}</h1>
  <div class="subtitle">${escape(l10n.exportGeneratedOn(DateFormat.yMMMMd(locale).add_Hm().format(generatedAt)))}</div>

  <div class="card-row">
    <div class="card income">
      <div class="card-title">${escape(l10n.exportTotalIncome)}</div>
      <div class="card-value">$totalIncome</div>
    </div>
    <div class="card expense">
      <div class="card-title">${escape(l10n.exportTotalExpenses)}</div>
      <div class="card-value">$totalExpense</div>
    </div>
    <div class="card">
      <div class="card-title">${escape(l10n.exportNetCashFlow)}</div>
      <div class="card-value">$totalNet</div>
    </div>
  </div>

  <h2>${escape(l10n.exportTransactionDetails)}</h2>
  <table>
    <thead>
      <tr>
        <th>${escape(l10n.exportColumnDate)}</th>
        <th>${escape(l10n.exportColumnMerchant)}</th>
        <th>${escape(l10n.exportColumnCategory)}</th>
        <th>${escape(l10n.exportColumnType)}</th>
        <th>${escape(l10n.exportColumnAmount)}</th>
      </tr>
    </thead>
    <tbody>
$rows    </tbody>
  </table>

  <div class="footer">${escape(l10n.exportFooter)}</div>
</body>
</html>
''';
}
