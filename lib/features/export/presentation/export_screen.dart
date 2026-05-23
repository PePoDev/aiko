import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/providers.dart';
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

    try {
      final transactions = await ref.read(transactionsProvider.future);
      final categories = await ref.read(categoriesProvider.future);

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
        _showMessage('No transactions found in this date range to export.');
        setState(() => _isExporting = false);
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

      if (_format == 'csv' || _format == 'excel') {
        final List<List<dynamic>> rows = [
          ['Date', 'Merchant', 'Category', 'Type', 'Amount', 'Note'],
        ];

        for (final tx in filtered) {
          final cat = categories.firstWhere(
            (c) => c.id == tx.categoryId,
            orElse: () => categories.first,
          );
          rows.add([
            DateFormat('yyyy-MM-dd HH:mm').format(tx.date),
            tx.merchant ?? '',
            cat.name,
            tx.type.name,
            tx.amount.amount.toDouble(),
            tx.note ?? '',
          ]);
        }

        final csvContent = csv.encode(rows);
        final file = File('${tempDir.path}/aiko_export_$timestamp.csv');

        if (_format == 'excel') {
          // UTF-8 BOM character to force Excel to correctly render currency symbols and commas
          await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...csvContent.codeUnits]);
        } else {
          await file.writeAsString(csvContent);
        }

        await SharePlus.instance.share(
          ShareParams(files: [XFile(file.path)], text: 'Aiko Financial Export'),
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

        final currencyFormat = NumberFormat.simpleCurrency(name: 'USD');

        final StringBuffer rowsBuffer = StringBuffer();
        for (final tx in filtered) {
          final cat = categories.firstWhere(
            (c) => c.id == tx.categoryId,
            orElse: () => categories.first,
          );
          final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(tx.date);
          final amountClass = tx.type == TransactionType.income
              ? 'amount-income'
              : 'amount-expense';
          final amountSign = tx.type == TransactionType.income ? '+' : '-';

          rowsBuffer.write('''
            <tr>
              <td>$dateStr</td>
              <td>${tx.merchant ?? 'N/A'}</td>
              <td>${cat.name}</td>
              <td class="type-caps">${tx.type.name}</td>
              <td class="$amountClass">$amountSign ${currencyFormat.format(tx.amount.amount.toDouble())}</td>
            </tr>
          ''');
        }

        final htmlContent =
            '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Aiko Financial Statement</title>
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
  <h1>Aiko Financial Statement</h1>
  <div class="subtitle">Generated on ${DateFormat('MMMM dd, yyyy HH:mm').format(DateTime.now())} | Your financial companion: Aiko</div>
  
  <div class="card-row">
    <div class="card income">
      <div class="card-title">Total Income</div>
      <div class="card-value">${currencyFormat.format(incomeVal)}</div>
    </div>
    <div class="card expense">
      <div class="card-title">Total Expenses</div>
      <div class="card-value">${currencyFormat.format(expenseVal)}</div>
    </div>
    <div class="card">
      <div class="card-title">Net Cash Flow</div>
      <div class="card-value">${currencyFormat.format(netVal)}</div>
    </div>
  </div>

  <h2>Transaction Details</h2>
  <table>
    <thead>
      <tr>
        <th>Date</th>
        <th>Merchant</th>
        <th>Category</th>
        <th>Type</th>
        <th>Amount</th>
      </tr>
    </thead>
    <tbody>
      ${rowsBuffer.toString()}
    </tbody>
  </table>
  
  <div class="footer">Aiko — Supportive, smart, and secure personal finance tracker.</div>
</body>
</html>
        ''';

        final file = File('${tempDir.path}/aiko_statement_$timestamp.html');
        await file.writeAsString(htmlContent);

        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: 'Aiko PDF / HTML Statement',
          ),
        );
      }

      _showMessage('Export generated successfully!');
    } catch (e) {
      _showMessage('Unable to perform export: $e');
    } finally {
      setState(() => _isExporting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export Hub')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // 1. Date Range Card
          FinanceCard(
            title: '1. Choose Date Range',
            icon: Icons.calendar_today_outlined,
            accentColor: AikoColors.deepBlue,
            child: RadioGroup<String>(
              groupValue: _dateRange,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _dateRange = value);
                }
              },
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: const Text('Current Month'),
                    subtitle: const Text('Only transactions posted this month'),
                    value: 'current_month',
                  ),
                  RadioListTile<String>(
                    title: const Text('Last Month'),
                    subtitle: const Text('Only transactions posted last month'),
                    value: 'last_month',
                  ),
                  RadioListTile<String>(
                    title: const Text('All Time'),
                    subtitle: const Text('Export full historical ledger'),
                    value: 'all_time',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Format Selection Card
          FinanceCard(
            title: '2. Select Format',
            icon: Icons.article_outlined,
            accentColor: AikoColors.warningOrange,
            child: RadioGroup<String>(
              groupValue: _format,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _format = value);
                }
              },
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: const Text('Export CSV'),
                    subtitle: const Text('Raw comma-separated data values'),
                    value: 'csv',
                  ),
                  RadioListTile<String>(
                    title: const Text('Excel Spreadsheet'),
                    subtitle: const Text(
                      'CSV format with forced UTF-8 BOM encoding',
                    ),
                    value: 'excel',
                  ),
                  RadioListTile<String>(
                    title: const Text('PDF / HTML Statement'),
                    subtitle: const Text(
                      'Styled offline report invoice summary',
                    ),
                    value: 'pdf',
                  ),
                ],
              ),
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
              _isExporting ? 'Generating Report...' : 'Share Export Document',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Exports are generated completely offline on your device to guarantee absolute privacy.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
