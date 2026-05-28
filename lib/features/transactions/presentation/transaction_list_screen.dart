import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/money/money.dart';
import '../../../shared/widgets/screen_states.dart';
import '../../../theme/aiko_colors.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/presentation/accounts_screen.dart';
import '../../categories/presentation/category_management_screen.dart';
import '../domain/transaction.dart';
import 'transaction_detail_screen.dart';
import 'transaction_form_screen.dart';
import 'transaction_rules_screen.dart';

class TransactionListScreen extends ConsumerStatefulWidget {
  const TransactionListScreen({super.key});

  @override
  ConsumerState<TransactionListScreen> createState() =>
      _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _startSearch() {
    setState(() => _isSearching = true);
  }

  void _stopSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search transactions',
                  prefixIcon: Icon(Icons.search),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              )
            : const Text('Transactions'),
        actions: [
          if (_isSearching)
            IconButton(
              tooltip: 'Close search',
              onPressed: _stopSearch,
              icon: const Icon(Icons.close),
            )
          else
            IconButton(
              tooltip: 'Search',
              onPressed: _startSearch,
              icon: const Icon(Icons.search),
            ),
          IconButton(
            tooltip: 'Accounts',
            onPressed: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(builder: (_) => const AccountsScreen()),
            ),
            icon: const Icon(Icons.account_balance_wallet_outlined),
          ),
          IconButton(
            tooltip: 'Categories',
            onPressed: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(
                builder: (_) => const CategoryManagementScreen(),
              ),
            ),
            icon: const Icon(Icons.category_outlined),
          ),
          IconButton(
            tooltip: 'Rules',
            onPressed: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(
                builder: (_) => const TransactionRulesScreen(),
              ),
            ),
            icon: const Icon(Icons.rule),
          ),
        ],
      ),
      body: transactionsAsync.when(
        loading: () => const AikoScreenState.loading(),
        error: (err, stack) => AikoScreenState.error(
          title: 'Transactions are unavailable',
          message: 'Aiko could not load this list right now. $err',
        ),
        data: (transactions) {
          return _MonthlyTransactionTabs(
            transactions: transactions,
            searchQuery: _searchQuery,
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder: (_) => const TransactionFormScreen(),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _MonthlyTransactionTabs extends StatelessWidget {
  const _MonthlyTransactionTabs({
    required this.transactions,
    required this.searchQuery,
  });

  final List<FinanceTransaction> transactions;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    final currentMonth = _MonthKey.fromDate(DateTime.now());
    final months = _monthKeysFor(transactions, currentMonth);
    final initialIndex = months.indexOf(currentMonth);

    return DefaultTabController(
      length: months.length,
      initialIndex: initialIndex < 0 ? 0 : initialIndex,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              tabs: [for (final month in months) Tab(text: month.label)],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final month in months)
                  _TransactionMonthPage(
                    transactions: _transactionsForMonth(month, transactions),
                    allTransactions: transactions,
                    searchQuery: searchQuery,
                    monthLabel: month.label,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static List<_MonthKey> _monthKeysFor(
    List<FinanceTransaction> transactions,
    _MonthKey currentMonth,
  ) {
    var firstMonth = currentMonth.addMonths(-120);
    var lastMonth = currentMonth.addMonths(120);

    for (final transaction in transactions) {
      final transactionMonth = _MonthKey.fromDate(transaction.date);
      if (transactionMonth.compareTo(firstMonth) < 0) {
        firstMonth = transactionMonth.addMonths(-12);
      }
      if (transactionMonth.compareTo(lastMonth) > 0) {
        lastMonth = transactionMonth.addMonths(12);
      }
    }

    return [
      for (
        var month = firstMonth;
        month.compareTo(lastMonth) <= 0;
        month = month.addMonths(1)
      )
        month,
    ];
  }

  static List<FinanceTransaction> _transactionsForMonth(
    _MonthKey month,
    List<FinanceTransaction> transactions,
  ) {
    return transactions
        .where((transaction) => _MonthKey.fromDate(transaction.date) == month)
        .toList(growable: false);
  }
}

class _TransactionMonthPage extends ConsumerWidget {
  const _TransactionMonthPage({
    required this.transactions,
    required this.allTransactions,
    required this.searchQuery,
    required this.monthLabel,
  });

  final List<FinanceTransaction> transactions;
  final List<FinanceTransaction> allTransactions;
  final String searchQuery;
  final String monthLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtered = transactions.where((tx) {
      if (searchQuery.isEmpty) return true;
      final query = searchQuery.toLowerCase();
      return (tx.merchant ?? '').toLowerCase().contains(query) ||
          (tx.note ?? '').toLowerCase().contains(query) ||
          tx.tags.any((tag) => tag.toLowerCase().contains(query));
    }).toList()..sort((a, b) => b.date.compareTo(a.date));

    if (filtered.isEmpty) {
      return AikoScreenState.empty(
        title: 'No transactions in $monthLabel',
        message: searchQuery.isEmpty
            ? 'Add a transaction for this month when you are ready.'
            : 'Try another search, or switch to another month.',
      );
    }

    final groups = _groupTransactionsByDate(filtered);
    final accounts =
        ref.watch(accountsProvider).whenOrNull(data: (accounts) => accounts) ??
        const <Account>[];
    final accountLabels = _accountLabelsForTransactions(
      transactions: filtered,
      allTransactions: allTransactions,
      accounts: accounts,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
      children: [
        for (final group in groups) ...[
          _TransactionDateHeader(date: group.date),
          for (final tx in group.transactions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CompactTransactionCard(
                transaction: tx,
                accountLabel: accountLabels[tx.id] ?? 'Unknown',
                accent: tx.type == TransactionType.income
                    ? AikoColors.successGreen
                    : AikoColors.dangerRed,
                sign: tx.type == TransactionType.income ? '+' : '-',
                onTap: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TransactionDetailScreen(transaction: tx),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  List<_TransactionDateGroup> _groupTransactionsByDate(
    List<FinanceTransaction> transactions,
  ) {
    final grouped = <DateTime, List<FinanceTransaction>>{};
    for (final transaction in transactions) {
      final date = _dateOnly(transaction.date);
      grouped.putIfAbsent(date, () => []).add(transaction);
    }

    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final date in dates)
        _TransactionDateGroup(
          date: date,
          transactions: grouped[date]!
            ..sort((a, b) => b.date.compareTo(a.date)),
        ),
    ];
  }
}

class _TransactionDateGroup {
  const _TransactionDateGroup({required this.date, required this.transactions});

  final DateTime date;
  final List<FinanceTransaction> transactions;
}

Map<String, String> _accountLabelsForTransactions({
  required List<FinanceTransaction> transactions,
  required List<FinanceTransaction> allTransactions,
  required List<Account> accounts,
}) {
  final accountsById = {for (final account in accounts) account.id: account};
  final balancesByAccountId = {
    for (final account in accounts) account.id: account.openingBalance,
  };
  final visibleIds = transactions.map((transaction) => transaction.id).toSet();
  final labels = <String, String>{};
  final sorted = [...allTransactions]..sort((a, b) => a.date.compareTo(b.date));

  for (final transaction in sorted) {
    final account = accountsById[transaction.accountId];
    final balanceBeforeTransaction = balancesByAccountId[transaction.accountId];
    if (balanceBeforeTransaction == null) {
      continue;
    }
    final balanceAfterTransaction = _balanceAfterTransaction(
      balanceBeforeTransaction,
      transaction,
    );
    balancesByAccountId[transaction.accountId] = balanceAfterTransaction;

    if (account != null && visibleIds.contains(transaction.id)) {
      labels[transaction.id] =
          '${account.name} (${balanceAfterTransaction.format()})';
    }
  }

  return labels;
}

Money _balanceAfterTransaction(
  Money balanceBeforeTransaction,
  FinanceTransaction transaction,
) {
  if (transaction.type == TransactionType.income) {
    return balanceBeforeTransaction + transaction.amount;
  }
  return balanceBeforeTransaction - transaction.amount;
}

class _TransactionDateHeader extends StatelessWidget {
  const _TransactionDateHeader({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Text(
        _dateHeaderLabel(date),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: AikoColors.mutedText,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MonthKey {
  const _MonthKey(this.year, this.month);

  factory _MonthKey.fromDate(DateTime date) {
    return _MonthKey(date.year, date.month);
  }

  final int year;
  final int month;

  String get label => '${_monthLabels[month - 1]} $year';

  _MonthKey addMonths(int offset) {
    final zeroBasedMonth = (year * 12) + (month - 1) + offset;
    return _MonthKey(zeroBasedMonth ~/ 12, (zeroBasedMonth % 12) + 1);
  }

  int compareTo(_MonthKey other) {
    final yearCompare = year.compareTo(other.year);
    if (yearCompare != 0) {
      return yearCompare;
    }
    return month.compareTo(other.month);
  }

  @override
  bool operator ==(Object other) {
    return other is _MonthKey && other.year == year && other.month == month;
  }

  @override
  int get hashCode => Object.hash(year, month);
}

const _monthLabels = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

class _CompactTransactionCard extends ConsumerWidget {
  const _CompactTransactionCard({
    required this.transaction,
    required this.accountLabel,
    required this.accent,
    required this.sign,
    required this.onTap,
  });

  final FinanceTransaction transaction;
  final String accountLabel;
  final Color accent;
  final String sign;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = transaction.merchant ?? transaction.note ?? 'Transaction';
    final amount = '$sign${transaction.amount.format()}';
    final tagsLabel = transaction.tags.map((tag) => '#$tag').join(' ');
    final radius = BorderRadius.circular(8);
    final categoriesAsync = ref.watch(categoriesProvider);
    final categoryIcon =
        categoriesAsync.whenOrNull(
          data: (categories) {
            final matches = categories.where(
              (category) => category.id == transaction.categoryId,
            );
            if (matches.isEmpty) {
              return null;
            }
            return _categoryIconFor(matches.first.icon);
          },
        ) ??
        (transaction.type == TransactionType.income
            ? Icons.south_west
            : Icons.north_east);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(categoryIcon, color: accent, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (tagsLabel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        tagsLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AikoColors.mutedText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 132),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      amount,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      accountLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AikoColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
        ),
      ),
    );
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
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

String _dateHeaderLabel(DateTime date) {
  final today = _dateOnly(DateTime.now());
  if (date == today) {
    return 'Today';
  }
  if (date == today.subtract(const Duration(days: 1))) {
    return 'Yesterday';
  }
  return DateFormat('EEE, MMM d, yyyy').format(date);
}
