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
import '../application/export_builder.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  String _dateRange =
      'current_month'; // 'current_month', 'last_month', 'all_time'
  // 'csv', 'excel' (CSV with a byte-order mark so Excel reads Thai), or
  // 'html' (a statement to print to PDF from the browser).
  String _format = 'csv';
  bool _isExporting = false;

  Future<void> _exportData() async {
    setState(() => _isExporting = true);
    final l10n = context.l10n;

    try {
      final transactions = await ref.read(transactionsProvider.future);
      // Includes deleted custom categories so exported rows keep a name.
      final categories = await ref.read(allCategoriesProvider.future);
      final accounts = await ref.read(accountsProvider.future);

      final categoriesById = {for (final c in categories) c.id: c};
      final accountNames = {for (final a in accounts) a.id: a.name};
      String categoryName(FinanceTransaction tx) =>
          categoriesById[tx.categoryId]?.displayName(l10n) ??
          l10n.uncategorized;
      String accountName(FinanceTransaction tx) =>
          accountNames[tx.accountId] ?? '';

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
        final rows = buildExportCsvRows(
          transactions: filtered,
          l10n: l10n,
          categoryName: categoryName,
          accountName: accountName,
        );
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
      } else {
        final htmlContent = buildStatementHtml(
          transactions: filtered,
          l10n: l10n,
          categoryName: categoryName,
          baseCurrency:
              ref.read(profileProvider).value?.baseCurrency ??
              kDefaultBaseCurrency,
          generatedAt: DateTime.now(),
        );

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
                RadioGroup<String>(
                  groupValue: _format,
                  onChanged: (value) {
                    if (value != null) setState(() => _format = value);
                  },
                  child: Column(
                    children: [
                      const RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        value: 'csv',
                        title: Text('CSV'), // l10n-ignore
                        secondary: Icon(Icons.table_chart_outlined),
                      ),
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        value: 'excel',
                        title: Text(context.l10n.exportFormatExcelCsv),
                        secondary: const Icon(Icons.grid_on_outlined),
                      ),
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        value: 'html',
                        title: Text(context.l10n.exportFormatHtmlStatement),
                        secondary: const Icon(Icons.print_outlined),
                      ),
                    ],
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
