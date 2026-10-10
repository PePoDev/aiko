import '../../../theme/aiko_status_colors.dart';
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
import '../../../shared/widgets/screen_states.dart';
import '../../../theme/aiko_colors.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/transaction_detail_screen.dart';
import '../application/account_balances.dart';
import '../domain/account.dart';
import '../domain/account_details.dart';
import 'account_form/account_form_screen.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);
    final transactionsAsync = ref.watch(transactionsProvider);
    final baseCurrency =
        ref.watch(profileProvider).value?.baseCurrency ?? 'USD';

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.accountsTab),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: TextButton.icon(
              onPressed: () => _showAccountForm(context),
              icon: const Icon(Icons.add),
              label: Text(context.l10n.add),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.refresh(accountsProvider.future),
            ref.refresh(transactionsProvider.future),
          ]);
        },
        child: accountsAsync.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [AikoScreenState.loading()],
          ),
          error: (err, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              AikoScreenState.error(
                title: context.l10n.accountsUnavailableTitle,
                message: context.l10n.accountsUnavailableMessage,
              ),
            ],
          ),
          data: (accounts) {
            final transactions =
                transactionsAsync.whenOrNull(
                  data: (transactions) => transactions,
                ) ??
                const <FinanceTransaction>[];
            if (accounts.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  AikoScreenState.empty(
                    title: context.l10n.accountsEmptyTitle,
                    message: context.l10n.accountsEmptyMessage,
                    action: PrimaryActionButton(
                      label: context.l10n.accountsAddAccount,
                      icon: Icons.add_card_outlined,
                      onPressed: () => _showAccountForm(context),
                    ),
                  ),
                ],
              );
            }

            final accountSections = _groupAccountsByType(accounts);
            // One pass over the ledger per build; every figure below reads it.
            final balances = currentAccountBalances(accounts, transactions);
            final summary = summarizeAccounts(
              accounts: accounts,
              balances: balances,
              baseCurrency: baseCurrency,
            );

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
              children: [
                _AccountsSummaryCard(
                  accountCount: accounts.length,
                  total: summary.total,
                  netWorth: summary.netWorth,
                  baseCurrency: baseCurrency,
                  assets: summary.assets,
                  liabilities: summary.liabilities,
                ),
                const SizedBox(height: 16),
                for (final section in accountSections) ...[
                  _AccountTypeHeader(
                    type: section.type,
                    accountCount: section.accounts.length,
                    total: sumBalancesInCurrency(
                      accounts: section.accounts,
                      balances: balances,
                      baseCurrency: baseCurrency,
                    ),
                  ),
                  _AccountSectionCard(
                    children: section.accounts.isEmpty
                        ? [
                            _AddAccountPlaceholder(
                              type: section.type,
                              onTap: () => _showAccountForm(
                                context,
                                initialType: section.type,
                              ),
                            ),
                          ]
                        : [
                            for (final account in section.accounts)
                              _AccountListItem(
                                account: account,
                                currentBalance:
                                    balances[account.id] ??
                                    account.currentBalance,
                                onTap: () => openAikoPage<void>(
                                  context,
                                  AccountDetailScreen(account: account),
                                ),
                              ),
                          ],
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AccountsSummaryCard extends StatelessWidget {
  const _AccountsSummaryCard({
    required this.accountCount,
    required this.total,
    required this.netWorth,
    required this.baseCurrency,
    required this.assets,
    required this.liabilities,
  });

  final int accountCount;
  final Money? total;
  final Money? netWorth;
  final String baseCurrency;
  final Money? assets;
  final Money? liabilities;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FinanceCard(
      title: context.l10n.accountsSummary,
      icon: Icons.account_balance_wallet_outlined,
      accentColor: AikoColors.primaryBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            total?.format() ?? '—',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AikoColors.primaryBlue,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.accountsSummaryCount(accountCount, baseCurrency),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.accountsNetWorthValue(netWorth?.format() ?? '—'),
            key: const ValueKey('account-summary-net-worth'),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (assets != null || liabilities != null) ...[
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: context.l10n.accountsAssets,
                    value: (assets ?? Money.zero(baseCurrency)).format(),
                    icon: Icons.add_chart,
                    color: AikoColors.successGreen,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _MetricTile(
                    label: context.l10n.accountsLiabilities,
                    value: (liabilities ?? Money.zero(baseCurrency)).format(),
                    icon: Icons.remove_circle_outline,
                    color: AikoColors.dangerRed,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _AccountTypeSection {
  const _AccountTypeSection({required this.type, required this.accounts});

  final AccountType type;
  final List<Account> accounts;
}

List<_AccountTypeSection> _groupAccountsByType(List<Account> accounts) {
  return [
    for (final type in AccountType.values)
      _AccountTypeSection(
        type: type,
        accounts: [
          for (final account in accounts)
            if (account.type == type) account,
        ],
      ),
  ];
}

class _AccountTypeHeader extends StatelessWidget {
  const _AccountTypeHeader({
    required this.type,
    required this.accountCount,
    required this.total,
  });

  final AccountType type;
  final int accountCount;
  final Money? total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _colorForAccount(type);

    // Plain section label (no filled band) so it doesn't clash with the rounded
    // cards below. The accent comes through a small tinted tile matching the
    // account rows; the bold label carries the cue without color alone. The
    // trailing sum (in base currency) gives an at-a-glance total for the type.
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_iconForAccount(type), color: accent, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${type.label(context.l10n)} ($accountCount)',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          if (total != null) ...[
            const SizedBox(width: 8),
            Text(
              total!.format(),
              key: ValueKey('type-total-${type.name}'),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AikoStatusColors.of(context).textFor(accent),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

void _showAccountForm(
  BuildContext context, {
  Account? account,
  AccountType? initialType,
}) {
  openAikoPage<Account>(
    context,
    AccountFormScreen(account: account, initialType: initialType),
  );
}

void _showAccountSnackBar(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
    ),
  );
}

/// Groups one account-type section's rows into a single bordered card with
/// hairline dividers between them — mirrors the day-grouped transaction cards.
class _AccountSectionCard extends StatelessWidget {
  const _AccountSectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(8);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i != 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: 16,
                endIndent: 16,
                color: theme.colorScheme.outlineVariant,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _AccountListItem extends StatelessWidget {
  const _AccountListItem({
    required this.account,
    required this.currentBalance,
    required this.onTap,
  });

  final Account account;
  final Money currentBalance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _colorForAccount(account.type);

    return ListTile(
      onTap: onTap,
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      minLeadingWidth: 0,
      horizontalTitleGap: 12,
      leading: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(_iconForAccount(account.type), color: accent, size: 19),
      ),
      title: Text(
        account.name,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        _accountSubtitle(account, context.l10n),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Text(
        currentBalance.format(),
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _AddAccountPlaceholder extends StatelessWidget {
  const _AddAccountPlaceholder({required this.type, required this.onTap});

  final AccountType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _colorForAccount(type);

    return ListTile(
      onTap: onTap,
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      minLeadingWidth: 0,
      horizontalTitleGap: 12,
      leading: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.06),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.add, color: accent.withValues(alpha: 0.5), size: 19),
      ),
      title: Text(
        context.l10n.accountsAddType(type.label(context.l10n).toLowerCase()),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        size: 18,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
      ),
    );
  }
}

class AccountDetailScreen extends ConsumerStatefulWidget {
  const AccountDetailScreen({required this.account, super.key});

  final Account account;

  @override
  ConsumerState<AccountDetailScreen> createState() =>
      _AccountDetailScreenState();
}

class _AccountDetailScreenState extends ConsumerState<AccountDetailScreen> {
  late Account _account;

  @override
  void initState() {
    super.initState();
    _account = widget.account;
  }

  Future<void> _editAccount() async {
    final updated = await openAikoPage<Account>(
      context,
      AccountFormScreen(account: _account),
    );

    if (updated == null || !mounted) {
      return;
    }
    setState(() => _account = updated);
  }

  Future<void> _deleteAccount(int transactionCount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.accountsDeleteQuestion),
        content: Text(
          context.l10n.accountsDeleteConfirm(_account.name, transactionCount),
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
      final deleted = await ref
          .read(accountsProvider.notifier)
          .deleteAccount(_account.id);
      for (final transaction in deleted) {
        if (transaction.reminderAt != null) {
          unawaited(TransactionReminderService.instance.cancel(transaction.id));
        }
      }
      if (!mounted) {
        return;
      }
      _showAccountSnackBar(
        context,
        context.l10n.accountsDeleted(_account.name),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showAccountSnackBar(context, context.l10n.accountsDeleteFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _colorForAccount(_account.type);
    final transactions =
        ref
            .watch(transactionsProvider)
            .whenOrNull(data: (transactions) => transactions) ??
        const <FinanceTransaction>[];
    final accounts =
        ref.watch(accountsProvider).whenOrNull(data: (accounts) => accounts) ??
        const <Account>[];
    final relatedTransactions =
        transactions
            .where((transaction) => transaction.accountId == _account.id)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final currentBalance =
        currentAccountBalances([_account], relatedTransactions)[_account.id] ??
        _account.currentBalance;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.accountsDetailsTitle),
        actions: [
          IconButton(
            tooltip: context.l10n.accountsDeleteTooltip,
            onPressed: () => _deleteAccount(relatedTransactions.length),
            icon: const Icon(Icons.delete_outline),
          ),
          IconButton(
            tooltip: context.l10n.accountsEditTooltip,
            onPressed: _editAccount,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _iconForAccount(_account.type),
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _account.name,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(_accountSubtitle(_account, context.l10n)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    currentBalance.format(),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AikoStatusColors.of(context).textFor(accent),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _AccountDetailRow(
                    label: context.l10n.accountsDetailType,
                    value: _account.type.label(context.l10n),
                  ),
                  const Divider(),
                  _AccountDetailRow(
                    label: context.l10n.accountsNetWorth,
                    value: _account.includeInNetWorth
                        ? context.l10n.accountsIncluded
                        : context.l10n.accountsHidden,
                  ),
                  const Divider(),
                  _AccountDetailRow(
                    label: context.l10n.accountsStatus,
                    value: _account.isActive
                        ? context.l10n.accountsActive
                        : context.l10n.accountsInactive,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _AccountTypeDetailsCard(
            details: _account.resolvedDetails,
            accounts: accounts,
          ),
          const SizedBox(height: 12),
          _RelatedTransactionsCard(transactions: relatedTransactions),
        ],
      ),
    );
  }
}

class _RelatedTransactionsCard extends StatelessWidget {
  const _RelatedTransactionsCard({required this.transactions});

  /// Newest first.
  final List<FinanceTransaction> transactions;

  /// Rows shown; the full history lives on the Transactions tab.
  static const _maxShown = 20;

  @override
  Widget build(BuildContext context) {
    final shown = transactions.take(_maxShown).toList(growable: false);
    return FinanceCard(
      title: context.l10n.accountsRelatedTransactions,
      icon: Icons.receipt_long_outlined,
      accentColor: AikoColors.analyticsTeal,
      child: transactions.isEmpty
          ? Text(
              context.l10n.accountsNoTransactions,
              style: Theme.of(context).textTheme.bodyMedium,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < shown.length; index++) ...[
                  _RelatedTransactionTile(transaction: shown[index]),
                  if (index != shown.length - 1) const Divider(),
                ],
                if (transactions.length > shown.length) ...[
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      context.l10n.accountsRelatedShowingRecent(
                        shown.length,
                        transactions.length,
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _RelatedTransactionTile extends StatelessWidget {
  const _RelatedTransactionTile({required this.transaction});

  final FinanceTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.isInflow;
    final amount =
        '${isIncome ? '+' : '-'}${transaction.absoluteAmount.format()}';
    final title = transaction.merchant?.trim().isNotEmpty == true
        ? transaction.merchant!.trim()
        : transaction.note?.trim().isNotEmpty == true
        ? transaction.note!.trim()
        : transaction.type.label(context.l10n);
    final color = isIncome ? AikoColors.successGreen : AikoColors.dangerRed;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(
          isIncome ? Icons.south_west : Icons.north_east,
          color: color,
          size: 18,
        ),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(transaction.type.label(context.l10n)),
      trailing: Text(
        amount,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: AikoStatusColors.of(context).textFor(color),
          fontWeight: FontWeight.w800,
        ),
      ),
      onTap: () => openAikoPage<void>(
        context,
        TransactionDetailScreen(transaction: transaction),
      ),
    );
  }
}

class _AccountTypeDetailsCard extends StatelessWidget {
  const _AccountTypeDetailsCard({
    required this.details,
    required this.accounts,
  });
  final AccountDetails details;

  /// Every account, to name the card a credit card shares its limit with.
  final List<Account> accounts;

  String _accountName(String id, AppLocalizations l10n) {
    for (final account in accounts) {
      if (account.id == id) return account.name;
    }
    return l10n.txUnknownAccount;
  }

  List<(String, String)> _rowsFor(AccountDetails d, AppLocalizations l10n) {
    String day(DateTime date) => DateFormat.yMMMd().format(date);
    return switch (d) {
      CashDetails() => const [],
      BankDetails() => const [],
      EWalletDetails() => const [],
      CreditCardDetails() => [
        (l10n.accountsDetailStatementDay, '${d.statementDay}'),
        (l10n.accountsDetailDueDay, '${d.dueDay}'),
        if (d.creditLimit != null)
          (l10n.accountsDetailCreditLimit, d.creditLimit!.format()),
        if (d.aprPercent != null)
          (l10n.accountsDetailApr, '${d.aprPercent!.toStringAsFixed(2)}%'),
        if (d.rewardsType != null)
          (l10n.accountsDetailRewards, d.rewardsType!.label(l10n)),
        if (d.annualFee != null)
          (l10n.accountsDetailAnnualFee, d.annualFee!.format()),
        if (d.minimumPayment != null)
          (l10n.accountsDetailMinPayment, d.minimumPayment!.format()),
        (l10n.accountsDetailSharesLimit, d.sharesLimit ? l10n.yes : l10n.no),
        if (d.sharedLimitAccountId != null)
          (
            l10n.accountsDetailSharedWith,
            _accountName(d.sharedLimitAccountId!, l10n),
          ),
      ],
      LoanDetails() => [
        (l10n.accountsDetailType, d.loanType.label(l10n)),
        (l10n.accountsDetailPrincipal, d.principal.format()),
        (
          l10n.accountsDetailRate,
          '${d.interestRatePercent.toStringAsFixed(2)}%',
        ),
        (l10n.accountsDetailTerm, l10n.accountsDetailTermMonths(d.termMonths)),
        (l10n.accountsDetailMonthly, d.monthlyPayment.format()),
        (l10n.accountsDetailNextDue, day(d.nextDueDate)),
      ],
      InvestmentDetails() => [
        if (d.accountNumberLast4 != null)
          (l10n.accountsDetailLast4, d.accountNumberLast4!),
      ],
      AssetDetails() => [
        (l10n.accountsDetailClass, d.assetClass.label(l10n)),
        if (d.purchasePrice != null)
          (l10n.accountsDetailPurchasePrice, d.purchasePrice!.format()),
        if (d.purchaseDate != null)
          (l10n.accountsDetailPurchased, day(d.purchaseDate!)),
        if (d.notes != null) (l10n.accountsDetailNotes, d.notes!),
      ],
      LiabilityDetails() => [
        if (d.liabilityType != null)
          (l10n.accountsDetailType, d.liabilityType!),
        if (d.interestRatePercent != null)
          (
            l10n.accountsDetailRate,
            '${d.interestRatePercent!.toStringAsFixed(2)}%',
          ),
        if (d.notes != null) (l10n.accountsDetailNotes, d.notes!),
      ],
      OtherDetails() => [
        if (d.notes != null) (l10n.accountsDetailNotes, d.notes!),
      ],
    };
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rowsFor(details, context.l10n);
    if (rows.isEmpty) return const SizedBox.shrink();
    return FinanceCard(
      title: context.l10n.accountsTypeDetails,
      icon: Icons.list_alt_outlined,
      accentColor: AikoColors.deepBlue,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _DetailRow(label: rows[i].$1, value: rows[i].$2),
            if (i != rows.length - 1) const Divider(),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: Text(value, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}

class _AccountDetailRow extends StatelessWidget {
  const _AccountDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _iconForAccount(AccountType type) {
  return switch (type) {
    AccountType.cash => Icons.wallet_outlined,
    AccountType.bank => Icons.account_balance_outlined,
    AccountType.eWallet => Icons.account_balance_wallet_outlined,
    AccountType.creditCard => Icons.credit_card_outlined,
    AccountType.loan => Icons.handshake_outlined,
    AccountType.investment => Icons.trending_up_outlined,
    AccountType.asset => Icons.diamond_outlined,
    AccountType.liability => Icons.trending_down_outlined,
    AccountType.goal => Icons.flag_outlined,
    AccountType.other => Icons.category_outlined,
  };
}

Color _colorForAccount(AccountType type) {
  // Semantic where it fits: green = savings/income, orange = bills/limits,
  // red = debt, teal = portfolio/wealth. Reuses tokens, never one-off colors.
  return switch (type) {
    AccountType.cash => AikoColors.successGreen,
    AccountType.bank => AikoColors.deepBlue,
    AccountType.eWallet => AikoColors.primaryBlue,
    AccountType.creditCard => AikoColors.warningOrange,
    AccountType.loan => AikoColors.dangerRed,
    AccountType.investment => AikoColors.analyticsTeal,
    AccountType.asset => AikoColors.analyticsTeal,
    AccountType.liability => AikoColors.dangerRed,
    AccountType.goal => AikoColors.successGreen,
    AccountType.other => AikoColors.primaryBlue,
  };
}

String _accountSubtitle(Account account, AppLocalizations l10n) {
  return account.institution ??
      (account.type == AccountType.cash
          ? l10n.accountCashWallet
          : l10n.accountManualEntry);
}
