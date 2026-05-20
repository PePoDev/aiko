import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';
import '../domain/transaction.dart';

class TransactionDetailScreen extends StatelessWidget {
  const TransactionDetailScreen({required this.transaction, super.key});

  final FinanceTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final title = transaction.merchant ?? transaction.note ?? 'Transaction';
    final accent = transaction.type == TransactionType.income
        ? AikoColors.successGreen
        : AikoColors.deepBlue;
    final date = DateFormat.yMMMd().format(transaction.date);

    return Scaffold(
      appBar: AppBar(title: const Text('Transaction details')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          FinanceCard(
            title: title,
            icon: transaction.type == TransactionType.income
                ? Icons.south_west
                : Icons.north_east,
            accentColor: accent,
            prominent: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AmountText(_signedAmount(transaction)),
                const SizedBox(height: 8),
                Text('${_labelFor(transaction.type.name)} - $date'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FinanceCard(
            title: 'Details',
            icon: Icons.receipt_long_outlined,
            child: Column(
              children: [
                _DetailRow(
                  label: 'Status',
                  value: _labelFor(transaction.status.name),
                ),
                const Divider(),
                _DetailRow(label: 'Account', value: transaction.accountId),
                if (transaction.categoryId != null) ...[
                  const Divider(),
                  _DetailRow(label: 'Category', value: transaction.categoryId!),
                ],
                if (transaction.merchant != null) ...[
                  const Divider(),
                  _DetailRow(label: 'Merchant', value: transaction.merchant!),
                ],
                if (transaction.note != null &&
                    transaction.note!.isNotEmpty) ...[
                  const Divider(),
                  _DetailRow(label: 'Note', value: transaction.note!),
                ],
                if (transaction.tags.isNotEmpty) ...[
                  const Divider(),
                  _DetailRow(label: 'Tags', value: transaction.tags.join(', ')),
                ],
              ],
            ),
          ),
          if (transaction.splits.isNotEmpty) ...[
            const SizedBox(height: 16),
            FinanceCard(
              title: 'Splits',
              icon: Icons.call_split_outlined,
              accentColor: AikoColors.premiumPurple,
              child: Column(
                children: [
                  for (final split in transaction.splits) ...[
                    _DetailRow(
                      label: split.categoryId,
                      value: split.amount.format(),
                    ),
                    if (split != transaction.splits.last) const Divider(),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _signedAmount(FinanceTransaction transaction) {
    final sign = transaction.type == TransactionType.income ? '+' : '-';
    return '$sign${transaction.amount.format()}';
  }

  String _labelFor(String value) {
    final buffer = StringBuffer();
    for (var index = 0; index < value.length; index++) {
      final character = value[index];
      if (index > 0 && character.toUpperCase() == character) {
        buffer.write(' ');
      }
      buffer.write(index == 0 ? character.toUpperCase() : character);
    }
    return buffer.toString();
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AikoColors.mutedText,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
