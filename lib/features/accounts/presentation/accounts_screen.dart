import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/money/money.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../shared/widgets/screen_states.dart';
import '../../../theme/aiko_colors.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/transaction_detail_screen.dart';
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
        title: const Text('Accounts'),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: TextButton.icon(
              onPressed: () => _showAccountForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
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
                title: 'Accounts are unavailable',
                message: 'Aiko could not load your accounts right now. $err',
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
                    title: 'No accounts yet',
                    message:
                        'Add your cash, bank, card, or investment accounts.',
                    action: PrimaryActionButton(
                      label: 'Add account',
                      icon: Icons.add_card_outlined,
                      onPressed: () => _showAccountForm(context),
                    ),
                  ),
                ],
              );
            }

            final accountSections = _groupAccountsByType(accounts);
            final assetsLiabilities = _computeAssetsLiabilities(
              accounts: accounts,
              transactions: transactions,
              baseCurrency: baseCurrency,
            );

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
              children: [
                _AccountsSummaryCard(
                  accountCount: accounts.length,
                  total: _computeTotalBalance(
                    accounts: accounts,
                    transactions: transactions,
                    baseCurrency: baseCurrency,
                  ),
                  netWorth: _computeTotalBalance(
                    accounts: [
                      for (final a in accounts)
                        if (a.includeInNetWorth) a,
                    ],
                    transactions: transactions,
                    baseCurrency: baseCurrency,
                  ),
                  baseCurrency: baseCurrency,
                  assets: assetsLiabilities.assets,
                  liabilities: assetsLiabilities.liabilities,
                ),
                const SizedBox(height: 16),
                for (final section in accountSections) ...[
                  _AccountTypeHeader(
                    type: section.type,
                    accountCount: section.accounts.length,
                    total: _computeTypeTotal(
                      accounts: section.accounts,
                      transactions: transactions,
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
                                currentBalance: _currentBalanceForAccount(
                                  account,
                                  transactions,
                                ),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        AccountDetailScreen(account: account),
                                  ),
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
      title: 'Account summary',
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
            '$accountCount ${accountCount == 1 ? 'account' : 'accounts'} · total balance in $baseCurrency',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Net worth ${netWorth?.format() ?? '—'}',
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
                    label: 'Assets',
                    value: (assets ?? Money.zero(baseCurrency)).format(),
                    icon: Icons.add_chart,
                    color: AikoColors.successGreen,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _MetricTile(
                    label: 'Liabilities',
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
              '${_accountTypeLabel(type)} ($accountCount)',
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
                color: accent,
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
  Navigator.of(context).push<Account>(
    MaterialPageRoute(
      builder: (_) =>
          AccountFormScreen(account: account, initialType: initialType),
    ),
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
        _accountSubtitle(account),
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
        'Add ${_accountTypeLabel(type).toLowerCase()}',
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
    final updated = await Navigator.of(context).push<Account>(
      MaterialPageRoute(builder: (_) => AccountFormScreen(account: _account)),
    );

    if (updated == null || !mounted) {
      return;
    }
    setState(() => _account = updated);
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: Text(
          'Are you sure you want to delete "${_account.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await ref.read(accountsProvider.notifier).deleteAccount(_account.id);
      if (!mounted) {
        return;
      }
      _showAccountSnackBar(context, 'Account "${_account.name}" deleted.');
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showAccountSnackBar(context, 'Unable to delete account right now.');
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
    final relatedTransactions =
        transactions
            .where((transaction) => transaction.accountId == _account.id)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final currentBalance = _currentBalanceForAccount(_account, transactions);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account details'),
        actions: [
          IconButton(
            tooltip: 'Delete account',
            onPressed: _deleteAccount,
            icon: const Icon(Icons.delete_outline),
          ),
          IconButton(
            tooltip: 'Edit account',
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
                            Text(_accountSubtitle(_account)),
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
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _AccountDetailRow(
                    label: 'Type',
                    value: _accountTypeLabel(_account.type),
                  ),
                  const Divider(),
                  _AccountDetailRow(
                    label: 'Net worth',
                    value: _account.includeInNetWorth ? 'Included' : 'Hidden',
                  ),
                  const Divider(),
                  _AccountDetailRow(
                    label: 'Status',
                    value: _account.isActive ? 'Active' : 'Inactive',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _AccountTypeDetailsCard(details: _account.resolvedDetails),
          const SizedBox(height: 12),
          _RelatedTransactionsCard(transactions: relatedTransactions),
        ],
      ),
    );
  }
}

class _RelatedTransactionsCard extends StatelessWidget {
  const _RelatedTransactionsCard({required this.transactions});

  final List<FinanceTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    return FinanceCard(
      title: 'Related transactions',
      icon: Icons.receipt_long_outlined,
      accentColor: AikoColors.analyticsTeal,
      child: transactions.isEmpty
          ? Text(
              'No transactions recorded for this account yet.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          : Column(
              children: [
                for (var index = 0; index < transactions.length; index++) ...[
                  _RelatedTransactionTile(transaction: transactions[index]),
                  if (index != transactions.length - 1) const Divider(),
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
    final isIncome = transaction.type == TransactionType.income;
    final amount = '${isIncome ? '+' : '-'}${transaction.amount.format()}';
    final title = transaction.merchant?.trim().isNotEmpty == true
        ? transaction.merchant!.trim()
        : transaction.note?.trim().isNotEmpty == true
        ? transaction.note!.trim()
        : _transactionTypeLabel(transaction.type);
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
      subtitle: Text(_transactionTypeLabel(transaction.type)),
      trailing: Text(
        amount,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TransactionDetailScreen(transaction: transaction),
        ),
      ),
    );
  }
}

class _AccountTypeDetailsCard extends StatelessWidget {
  const _AccountTypeDetailsCard({required this.details});
  final AccountDetails details;

  List<(String, String)> _rowsFor(AccountDetails d) {
    return switch (d) {
      CashDetails() => const [],
      BankDetails() => const [],
      EWalletDetails() => const [],
      CreditCardDetails() => [
        ('Statement day', '${d.statementDay}'),
        ('Due day', '${d.dueDay}'),
        if (d.creditLimit != null) ('Credit limit', d.creditLimit!.format()),
        if (d.aprPercent != null)
          ('APR', '${d.aprPercent!.toStringAsFixed(2)}%'),
        if (d.rewardsType != null) ('Rewards', d.rewardsType!.name),
        if (d.annualFee != null) ('Annual fee', d.annualFee!.format()),
        if (d.minimumPayment != null)
          ('Min payment', d.minimumPayment!.format()),
        ('Shares limit', d.sharesLimit ? 'Yes' : 'No'),
        if (d.sharedLimitAccountId != null)
          ('Shared with', d.sharedLimitAccountId!),
      ],
      LoanDetails() => [
        ('Type', d.loanType.name),
        ('Principal', d.principal.format()),
        ('Rate', '${d.interestRatePercent.toStringAsFixed(2)}%'),
        ('Term', '${d.termMonths} mo'),
        ('Monthly', d.monthlyPayment.format()),
        ('Next due', d.nextDueDate.toIso8601String().substring(0, 10)),
      ],
      InvestmentDetails() => [
        if (d.accountNumberLast4 != null) ('Last 4', d.accountNumberLast4!),
      ],
      AssetDetails() => [
        ('Class', d.assetClass.name),
        if (d.purchasePrice != null)
          ('Purchase price', d.purchasePrice!.format()),
        if (d.purchaseDate != null)
          ('Purchased', d.purchaseDate!.toIso8601String().substring(0, 10)),
        if (d.notes != null) ('Notes', d.notes!),
      ],
      LiabilityDetails() => [
        if (d.liabilityType != null) ('Type', d.liabilityType!),
        if (d.interestRatePercent != null)
          ('Rate', '${d.interestRatePercent!.toStringAsFixed(2)}%'),
        if (d.notes != null) ('Notes', d.notes!),
      ],
      OtherDetails() => [if (d.notes != null) ('Notes', d.notes!)],
    };
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rowsFor(details);
    if (rows.isEmpty) return const SizedBox.shrink();
    return FinanceCard(
      title: 'Type details',
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

Money _currentBalanceForAccount(
  Account account,
  Iterable<FinanceTransaction> transactions,
) {
  final accountTransactions = transactions.where(
    (transaction) => transaction.accountId == account.id,
  );
  if (accountTransactions.isEmpty) {
    return account.currentBalance;
  }

  var balance = Money.zero(account.currency);
  for (final transaction in accountTransactions) {
    balance = transaction.applyToAccountBalance(balance);
  }
  return balance;
}

/// Sum the current balance of every account in the section, restricted to the
/// user's base currency. Mixed-currency accounts are skipped rather than
/// converted (no FX path here) so the displayed total never mixes units.
Money? _computeTypeTotal({
  required List<Account> accounts,
  required List<FinanceTransaction> transactions,
  required String baseCurrency,
}) {
  Money? total;
  final upper = baseCurrency.toUpperCase();
  for (final account in accounts) {
    if (account.currency.toUpperCase() != upper) continue;
    final balance = _currentBalanceForAccount(account, transactions);
    total = total == null ? balance : total + balance;
  }
  return total;
}

/// Splits net-worth accounts into assets (positive current balances) and
/// liabilities (what's owed, from negative balances), restricted to the base
/// currency so units never mix. Sign-based rather than type-based so a card or
/// loan in credit counts correctly; assets − liabilities reconciles with net
/// worth. Either side is null when no account contributes.
({Money? assets, Money? liabilities}) _computeAssetsLiabilities({
  required List<Account> accounts,
  required List<FinanceTransaction> transactions,
  required String baseCurrency,
}) {
  Money? assets;
  Money? liabilities;
  final upper = baseCurrency.toUpperCase();
  for (final account in accounts) {
    if (!account.includeInNetWorth) continue;
    if (account.currency.toUpperCase() != upper) continue;
    final balance = _currentBalanceForAccount(account, transactions);
    if (balance.isNegative) {
      final owed = Money.zero(account.currency) - balance;
      liabilities = liabilities == null ? owed : liabilities + owed;
    } else {
      assets = assets == null ? balance : assets + balance;
    }
  }
  return (assets: assets, liabilities: liabilities);
}

/// Total balance across all accounts, restricted to the base currency (same
/// no-FX rule as [_computeTypeTotal] so units never mix).
Money? _computeTotalBalance({
  required List<Account> accounts,
  required List<FinanceTransaction> transactions,
  required String baseCurrency,
}) {
  return _computeTypeTotal(
    accounts: accounts,
    transactions: transactions,
    baseCurrency: baseCurrency,
  );
}

String _transactionTypeLabel(TransactionType type) {
  return switch (type) {
    TransactionType.income => 'Income',
    TransactionType.expense => 'Expense',
    TransactionType.transfer => 'Transfer',
    TransactionType.transferOut => 'Transfer out',
    TransactionType.transferIn => 'Transfer in',
    TransactionType.refund => 'Refund',
    TransactionType.investmentBuy => 'Investment buy',
    TransactionType.investmentSell => 'Investment sell',
    TransactionType.dividend => 'Dividend',
    TransactionType.interest => 'Interest',
    TransactionType.loanPayment => 'Loan payment',
    TransactionType.creditCardPayment => 'Credit card payment',
    TransactionType.taxPayment => 'Tax payment',
    TransactionType.fee => 'Fee',
    TransactionType.adjustment => 'Adjustment',
  };
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

String _accountSubtitle(Account account) {
  return account.institution ??
      (account.type == AccountType.cash ? 'Cash wallet' : 'Manual entry');
}

String _accountTypeLabel(AccountType type) {
  final name = type.name;
  final buffer = StringBuffer();
  for (var i = 0; i < name.length; i++) {
    final char = name[i];
    if (i > 0 && char.toUpperCase() == char) {
      buffer.write(' ');
    }
    buffer.write(i == 0 ? char.toUpperCase() : char);
  }
  return buffer.toString();
}
