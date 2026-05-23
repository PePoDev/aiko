import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';
import '../domain/transaction.dart';
import 'transaction_form_screen.dart';

class TransactionDetailScreen extends ConsumerStatefulWidget {
  const TransactionDetailScreen({required this.transaction, super.key});

  final FinanceTransaction transaction;

  @override
  ConsumerState<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState
    extends ConsumerState<TransactionDetailScreen> {
  late FinanceTransaction _transaction;

  @override
  void initState() {
    super.initState();
    _transaction = widget.transaction;
  }

  Future<void> _editTransaction() async {
    final updated = await Navigator.of(context).push<FinanceTransaction>(
      MaterialPageRoute(
        builder: (_) => TransactionFormScreen(initialTransaction: _transaction),
      ),
    );

    if (updated == null || !mounted) return;
    setState(() => _transaction = updated);
  }

  @override
  Widget build(BuildContext context) {
    final transaction = _transaction;
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
    final categoryIcon = transaction.categoryId != null
        ? categoriesAsync.whenOrNull(
                data: (categories) {
                  try {
                    final category = categories.firstWhere(
                      (c) => c.id == transaction.categoryId,
                    );
                    return _categoryIconFor(category.icon);
                  } catch (_) {
                    return Icons.category_outlined;
                  }
                },
              ) ??
              Icons.category_outlined
        : null;
    final categoryColor = transaction.categoryId != null
        ? categoriesAsync.whenOrNull(
                data: (categories) {
                  try {
                    final category = categories.firstWhere(
                      (c) => c.id == transaction.categoryId,
                    );
                    return _parseHexColor(category.color);
                  } catch (_) {
                    return AikoColors.primaryBlue;
                  }
                },
              ) ??
              AikoColors.primaryBlue
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction details'),
        actions: [
          IconButton(
            tooltip: 'Edit transaction',
            onPressed: _editTransaction,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
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
                const SizedBox(height: 12),
                _DetailRow(label: 'Account', value: accountName),
                if (categoryName != null) ...[
                  const Divider(),
                  _DetailRow(
                    label: 'Category',
                    value: categoryName,
                    valueIcon: categoryIcon,
                    valueIconColor: categoryColor,
                  ),
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

  IconData _categoryIconFor(String iconName) {
    switch (iconName) {
      case 'food':
        return Icons.restaurant_outlined;
      case 'housing':
        return Icons.home_outlined;
      case 'travel':
        return Icons.flight_outlined;
      case 'coffee':
        return Icons.coffee_outlined;
      case 'shopping':
        return Icons.shopping_bag_outlined;
      case 'savings':
        return Icons.savings_outlined;
      case 'investing':
        return Icons.trending_up_outlined;
      case 'gym':
        return Icons.fitness_center_outlined;
      case 'salary':
        return Icons.attach_money_outlined;
      case 'entertainment':
        return Icons.movie_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  Color _parseHexColor(String hexStr) {
    try {
      final hexColor = hexStr.replaceAll('#', '');
      return Color(int.parse('FF$hexColor', radix: 16));
    } catch (_) {
      return AikoColors.primaryBlue;
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueIcon,
    this.valueIconColor,
  });

  final String label;
  final String value;
  final IconData? valueIcon;
  final Color? valueIconColor;

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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (valueIcon != null) ...[
                  Icon(
                    valueIcon,
                    key: const Key('transaction-category-icon'),
                    size: 18,
                    color: valueIconColor ?? AikoColors.primaryBlue,
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
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
    final categoryName =
        (categoriesAsync.whenOrNull(
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
                split.categoryId)
            as String;

    return _DetailRow(label: categoryName, value: split.amount.format());
  }
}
