import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';
import '../domain/transaction.dart';

class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({required this.transaction, super.key});

  final FinanceTransaction transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = transaction.merchant ?? transaction.note ?? 'Transaction';
    final accent = transaction.type == TransactionType.income
        ? AikoColors.successGreen
        : AikoColors.deepBlue;
    final dateTime = DateFormat('yyyy-MM-dd HH:mm').format(transaction.date);

    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    final accountName =
        accountsAsync.whenOrNull(
          data: (accounts) {
            try {
              final account = accounts.firstWhere(
                (a) => a.id == transaction.accountId,
              );
              return account.name;
            } catch (_) {
              return transaction.accountId;
            }
          },
        ) ??
        transaction.accountId;

    final categoryName = transaction.categoryId != null
        ? categoriesAsync.whenOrNull(
                data: (categories) {
                  try {
                    final category = categories.firstWhere(
                      (c) => c.id == transaction.categoryId,
                    );
                    return category.name;
                  } catch (_) {
                    return transaction.categoryId;
                  }
                },
              ) ??
              transaction.categoryId
        : null;

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
                Text(
                  '${_labelFor(transaction.type.name)} - $dateTime',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FinanceCard(
            title: 'Details',
            icon: Icons.receipt_long_outlined,
            child: Column(
              children: [
                _DetailRow(label: 'Transaction ID', value: transaction.id),
                const Divider(),
                _DetailRow(
                  label: 'Status',
                  value: _labelFor(transaction.status.name),
                ),
                const Divider(),
                _DetailRow(
                  label: 'Type',
                  value: _labelFor(transaction.type.name),
                ),
                const Divider(),
                _DetailRow(label: 'Account', value: accountName),
                if (categoryName != null) ...[
                  const Divider(),
                  _DetailRow(label: 'Category', value: categoryName),
                ],
                const Divider(),
                _DetailRow(label: 'Amount', value: transaction.amount.format()),
                const Divider(),
                _DetailRow(
                  label: 'Currency',
                  value: transaction.amount.currency,
                ),
                const Divider(),
                _DetailRow(label: 'Date & Time', value: dateTime),
                if (transaction.merchant != null &&
                    transaction.merchant!.isNotEmpty) ...[
                  const Divider(),
                  _DetailRow(label: 'Title', value: transaction.merchant!),
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
                    _SplitRow(split: split, categoriesAsync: categoriesAsync),
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

class _SplitRow extends StatelessWidget {
  const _SplitRow({required this.split, required this.categoriesAsync});

  final TransactionSplit split;
  final AsyncValue categoriesAsync;

  @override
  Widget build(BuildContext context) {
    final categoryName = (categoriesAsync.whenOrNull(
          data: (categories) {
            try {
              final category = categories.firstWhere(
                (c) => c.id == split.categoryId,
              );
              return category.name;
            } catch (_) {
              return split.categoryId;
            }
          },
        ) ??
        split.categoryId) as String;

    return _DetailRow(label: categoryName, value: split.amount.format());
  }
}
