import '../../../l10n/domain_labels.dart';
import '../../../l10n/l10n.dart';
import '../../categories/presentation/category_names.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/providers.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';
import '../../transactions/domain/transaction.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  String _dateRange =
      'current_month'; // 'current_month', 'last_month', 'all_time'
  String _format = 'csv'; // 'csv', 'excel', 'pdf'
  bool _isExporting = false;

  Future<void> _exportData() async {
    setState(() => _isExporting = true);
    final l10n = context.l10n;

    try {
      final transactions = await ref.read(transactionsProvider.future);
      final categories = await ref.read(categoriesProvider.future);

      final categoriesById = {for (final c in categories) c.id: c};
      String categoryName(FinanceTransaction tx) =>
          categoriesById[tx.categoryId]?.displayName(l10n) ??
          l10n.uncategorized;
      const htmlEscape = HtmlEscape();
      String escape(String text) => htmlEscape.convert(text);

      final now = DateTime.now();
      final filtered = transactions.where((tx) {
        if (_dateRange == 'current_month') {
          return tx.date.year == now.year && tx.date.month == now.month;
        } else if (_dateRange == 'last_month') {
          final lastMonthDate = DateTime(now.year, now.month - 1);
          return tx.date.year == lastMonthDate.year &&
              tx.date.month == lastMonthDate.month;
        }
        return true; // all_time
      }).toList();

      if (filtered.isEmpty) {
        _showMessage(l10n.exportNoTransactions);
        setState(() => _isExporting = false);
        return;
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

      if (_format == 'csv' || _format == 'excel') {
        final List<List<dynamic>> rows = [
          [
            l10n.exportColumnDate,
            l10n.exportColumnMerchant,
            l10n.exportColumnCategory,
            l10n.exportColumnType,
            l10n.exportColumnAmount,
            l10n.exportColumnNote,
          ],
        ];

        for (final tx in filtered) {
          rows.add([
            DateFormat('yyyy-MM-dd HH:mm').format(tx.date),
            tx.merchant ?? '',
            categoryName(tx),
            tx.type.label(l10n),
            tx.amount.amount.toString(),
            tx.note ?? '',
          ]);
        }

        final csvContent = csv.encode(rows);
        final bytes = Uint8List.fromList([
          if (_format == 'excel') ...[0xEF, 0xBB, 0xBF],
          ...utf8.encode(csvContent),
        ]);
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile.fromData(bytes, mimeType: 'text/csv')],
            fileNameOverrides: ['aiko_export_$timestamp.csv'],
            text: l10n.exportShareCsvText,
          ),
        );
      } else if (_format == 'pdf') {
        // Generate beautiful HTML layout
        final double incomeVal = filtered
            .where((tx) => tx.type == TransactionType.income)
            .fold(0.0, (sum, tx) => sum + tx.amount.amount.toDouble());
        final double expenseVal = filtered
            .where((tx) => tx.type == TransactionType.expense)
            .fold(0.0, (sum, tx) => sum + tx.amount.amount.toDouble());
        final double netVal = incomeVal - expenseVal;

        final baseCurrency =
            ref.read(profileProvider).value?.baseCurrency ??
            kDefaultBaseCurrency;
        final currencyFormat = NumberFormat.simpleCurrency(name: baseCurrency);

        final StringBuffer rowsBuffer = StringBuffer();
        for (final tx in filtered) {
          final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(tx.date);
          final amountClass = tx.isInflow ? 'amount-income' : 'amount-expense';
          final amountSign = tx.isInflow ? '+' : '-';

          rowsBuffer.write('''
            <tr>
              <td>$dateStr</td>
              <td>${escape(tx.merchant ?? '—')}</td>
              <td>${escape(categoryName(tx))}</td>
              <td class="type-caps">${escape(tx.type.label(l10n))}</td>
              <td class="$amountClass">$amountSign ${currencyFormat.format(tx.absoluteAmount.amount.toDouble())}</td>
            </tr>
          ''');
        }

        final htmlContent =
            '''
<!DOCTYPE html>
<html lang="${l10n.localeName}">
<head>
  <meta charset="utf-8">
  <title>${l10n.exportStatementTitle}</title>
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
    .amount-income { color: #10B981; font-weight: bold; }
    .amount-expense { color: #EF4444; font-weight: bold; }
    .footer { margin-top: 50px; text-align: center; font-size: 11px; color: #999; border-top: 1px solid #eee; padding-top: 20px; }
  </style>
</head>
<body>
  <h1>${l10n.exportStatementTitle}</h1>
  <div class="subtitle">${escape(l10n.exportGeneratedOn(DateFormat.yMMMMd().add_Hm().format(DateTime.now())))}</div>
  
  <div class="card-row">
    <div class="card income">
      <div class="card-title">${l10n.exportTotalIncome}</div>
      <div class="card-value">${currencyFormat.format(incomeVal)}</div>
    </div>
    <div class="card expense">
      <div class="card-title">${l10n.exportTotalExpenses}</div>
      <div class="card-value">${currencyFormat.format(expenseVal)}</div>
    </div>
    <div class="card">
      <div class="card-title">${l10n.exportNetCashFlow}</div>
      <div class="card-value">${currencyFormat.format(netVal)}</div>
    </div>
  </div>

  <h2>${l10n.exportTransactionDetails}</h2>
  <table>
    <thead>
      <tr>
        <th>${l10n.exportColumnDate}</th>
        <th>${l10n.exportColumnMerchant}</th>
        <th>${l10n.exportColumnCategory}</th>
        <th>${l10n.exportColumnType}</th>
        <th>${l10n.exportColumnAmount}</th>
      </tr>
    </thead>
    <tbody>
      ${rowsBuffer.toString()}
    </tbody>
  </table>
  
  <div class="footer">${escape(l10n.exportFooter)}</div>
</body>
</html>
        ''';

        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile.fromData(
                Uint8List.fromList(utf8.encode(htmlContent)),
                mimeType: 'text/html',
              ),
            ],
            fileNameOverrides: ['aiko_statement_$timestamp.html'],
            text: l10n.exportShareStatementText,
          ),
        );
      }

      _showMessage(l10n.exportSuccess);
    } catch (e) {
      debugPrint('[export] failed: $e');
      _showMessage(l10n.exportFailed);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.exportTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // Export Settings Card
          FinanceCard(
            title: context.l10n.exportSettings,
            icon: Icons.tune_outlined,
            accentColor: AikoColors.deepBlue,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.exportDateRange,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'current_month',
                        label: Text(context.l10n.exportThisMonth),
                      ),
                      ButtonSegment(
                        value: 'last_month',
                        label: Text(context.l10n.exportLastMonth),
                      ),
                      ButtonSegment(
                        value: 'all_time',
                        label: Text(context.l10n.exportAllTime),
                      ),
                    ],
                    selected: {_dateRange},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() => _dateRange = newSelection.first);
                    },
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  context.l10n.exportFormat,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'csv',
                        label: Text('CSV'), // l10n-ignore
                      ),
                      ButtonSegment(
                        value: 'excel',
                        label: Text('Excel'), // l10n-ignore
                      ),
                      ButtonSegment(
                        value: 'pdf',
                        label: Text('PDF'), // l10n-ignore
                      ),
                    ],
                    selected: {_format},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() => _format = newSelection.first);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 3. Export action button
          FilledButton.icon(
            onPressed: _isExporting ? null : _exportData,
            icon: _isExporting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.share_outlined),
            label: Text(
              _isExporting
                  ? context.l10n.exportGenerating
                  : context.l10n.exportShare,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.exportPrivacyNote,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
