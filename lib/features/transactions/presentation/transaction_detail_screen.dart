import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/money/money.dart';
import '../../../core/notifications/transaction_reminder_service.dart';
import '../../../l10n/domain_labels.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/layout/adaptive_presentation.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/presentation/accounts_screen.dart';
import '../../categories/domain/category.dart';
import '../../categories/presentation/category_editor_sheet.dart';
import '../../categories/presentation/category_names.dart';
import '../../categories/presentation/category_visual.dart';
import '../data/transaction_attachment_repository.dart';
import '../domain/transaction.dart';
import '../domain/transaction_attachment.dart';
import 'transaction_attachment_section.dart';
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
  final _attachmentRepository = TransactionAttachmentRepository();
  Stream<List<TransactionAttachment>>? _attachments;
  String? _attachmentsOf;

  /// The attachments of [transactionId], read by one listener while shown.
  Stream<List<TransactionAttachment>> _attachmentsFor(String transactionId) {
    if (_attachmentsOf != transactionId) {
      _attachmentsOf = transactionId;
      _attachments = _attachmentRepository.watchForTransaction(transactionId);
    }
    return _attachments!;
  }

  @override
  void initState() {
    super.initState();
    _transaction = widget.transaction;
  }

  Future<void> _editTransaction() async {
    final updated = await openAikoPage<FinanceTransaction>(
      context,
      TransactionFormScreen(initialTransaction: _transaction),
    );

    if (updated == null || !mounted) return;
    setState(() => _transaction = updated);
  }

  Future<void> _deleteTransaction() async {
    // A linked transfer leg is deleted together with its partner.
    final isLinkedTransfer = transferPartnersOf(
      _transaction,
      ref.read(transactionsProvider).value ?? const [],
    ).isNotEmpty;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.txDeleteQuestion),
        content: Text(
          isLinkedTransfer
              ? context.l10n.txDeleteTransferConfirm
              : context.l10n.txDeleteConfirm,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AikoColors.dangerRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: Text(context.l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      final deletedIds = await ref
          .read(transactionsProvider.notifier)
          .deleteTransaction(_transaction.id);
      for (final id in deletedIds) {
        await TransactionReminderService.instance.cancel(id);
      }
      // Their files go too; cloud copies are deleted once online.
      unawaited(_attachmentRepository.deleteForTransactions(deletedIds));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.txDeleted)));
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.txDeleteFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final transaction = _transaction;
    final title =
        transaction.merchant ?? transaction.note ?? context.l10n.txUntitled;
    final dateTime = DateFormat('yyyy-MM-dd HH:mm').format(transaction.date);

    final accountsAsync = ref.watch(accountsProvider);
    // Includes deleted (archived) categories so older transactions keep
    // their category name.
    final categoriesAsync = ref.watch(allCategoriesProvider);

    final account = accountsAsync.whenOrNull(
      data: (accounts) => _accountFor(accounts, transaction.accountId),
    );
    // A deleted account or category shows a readable fallback, never its id.
    final accountName = account?.name ?? context.l10n.txUnknownAccount;

    final category = transaction.categoryId == null
        ? null
        : categoriesAsync.whenOrNull(
            data: (categories) =>
                _categoryFor(categories, transaction.categoryId!),
          );
    final categoryName = transaction.categoryId == null
        ? null
        : category?.displayName(context.l10n) ?? context.l10n.uncategorized;
    final categoryIcon = transaction.categoryId != null
        ? (category == null
              ? Icons.category_outlined
              : aikoCategoryIcon(category.icon))
        : null;
    final categoryColor = transaction.categoryId != null
        ? (category == null
              ? AikoColors.primaryBlue
              : aikoHexColor(category.color))
        : null;
    final fallbackIcon = transaction.isInflow
        ? Icons.south_west
        : Icons.north_east;
    final accent =
        categoryColor ??
        (transaction.isInflow ? AikoColors.successGreen : AikoColors.deepBlue);
    // Adjustments mirror the account's balance; they're changed from there.
    final isAdjustment = transaction.type == TransactionType.adjustment;
    // A transfer's receipts are saved with its outflow leg.
    final attachmentsOf = transaction.type == TransactionType.transferIn
        ? transferPartnersOf(
                transaction,
                ref.watch(transactionsProvider).value ?? const [],
              ).firstOrNull?.id ??
              transaction.id
        : transaction.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.txDetailsTitle),
        actions: [
          IconButton(
            tooltip: context.l10n.txDeleteTooltip,
            onPressed: _deleteTransaction,
            icon: const Icon(Icons.delete_outline),
          ),
          if (!isAdjustment)
            IconButton(
              tooltip: context.l10n.txEditTitle,
              onPressed: _editTransaction,
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          FinanceCard(
            title: title,
            icon: categoryIcon ?? fallbackIcon,
            accentColor: accent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AmountText(_signedAmount(transaction)),
                const SizedBox(height: 4),
                Text(
                  '${transaction.type.label(context.l10n)} - $dateTime',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                _DetailRow(
                  label: context.l10n.txAccount,
                  value: accountName,
                  onTap: account == null
                      ? null
                      : () => openAikoPage<void>(
                          context,
                          AccountDetailScreen(account: account),
                        ),
                ),
                if (categoryName != null) ...[
                  const Divider(),
                  _DetailRow(
                    label: context.l10n.txCategory,
                    value: categoryName,
                    valueIcon: categoryIcon,
                    valueIconColor: categoryColor,
                    onTap: category == null || category.isDefault
                        ? null
                        : () => showCategoryEditorSheet(
                            context,
                            initialCategory: category,
                          ),
                  ),
                ],
                if (transaction.note != null &&
                    transaction.note!.isNotEmpty) ...[
                  const Divider(),
                  _DetailRow(
                    label: context.l10n.txNote,
                    value: transaction.note!,
                  ),
                ],
                if (transaction.tags.isNotEmpty) ...[
                  const Divider(),
                  _DetailRow(
                    label: context.l10n.txTags,
                    value: transaction.tags.join(', '),
                  ),
                ],
                if (isAdjustment) ...[
                  const Divider(),
                  Text(
                    context.l10n.txAdjustmentEditHint,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (transaction.reminderAt != null) ...[
                  const Divider(),
                  _DetailRow(
                    label: context.l10n.txReminder,
                    value: DateFormat(
                      'MMM d, yyyy · HH:mm',
                    ).format(transaction.reminderAt!),
                    valueIcon: Icons.notifications_active_outlined,
                  ),
                ],
              ],
            ),
          ),
          StreamBuilder<List<TransactionAttachment>>(
            stream: _attachmentsFor(attachmentsOf),
            builder: (context, snapshot) {
              final attachments = snapshot.data ?? const [];
              if (attachments.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: FinanceCard(
                  title: context.l10n.txAttachments,
                  icon: Icons.attach_file,
                  accentColor: AikoColors.deepBlue,
                  child: TransactionAttachmentSection(
                    attachments: attachments,
                    showTitle: false,
                    showUploadState: _attachmentRepository.uploadsToCloud,
                  ),
                ),
              );
            },
          ),
          if (transaction.splits.isNotEmpty) ...[
            const SizedBox(height: 16),
            FinanceCard(
              title: context.l10n.txSplits,
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
    final sign = transaction.isInflow ? '+' : '-';
    return '$sign${transaction.absoluteAmount.format()}';
  }

  Account? _accountFor(List<Account> accounts, String accountId) {
    for (final account in accounts) {
      if (account.id == accountId) {
        return account;
      }
    }
    return null;
  }

  Category? _categoryFor(List<Category> categories, String categoryId) {
    for (final category in categories) {
      if (category.id == categoryId) {
        return category;
      }
    }
    return null;
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueIcon,
    this.valueIconColor,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? valueIcon;
  final Color? valueIconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
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
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return row;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: row,
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
                      return category.displayName(context.l10n);
                    } catch (_) {
                      return context.l10n.uncategorized;
                    }
                  },
                ) ??
                context.l10n.uncategorized)
            as String;

    return _DetailRow(label: categoryName, value: split.amount.format());
  }
}
