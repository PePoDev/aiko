import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
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
  final _minAmountController = TextEditingController();
  final _maxAmountController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;
  _TransactionTypeFilter _typeFilter = _TransactionTypeFilter.all;
  _TransactionDateFilter _dateFilter = _TransactionDateFilter.all;
  bool _showAmountInputs = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
    _minAmountController.addListener(_onFilterChanged);
    _maxAmountController.addListener(_onFilterChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _minAmountController
      ..removeListener(_onFilterChanged)
      ..dispose();
    _maxAmountController
      ..removeListener(_onFilterChanged)
      ..dispose();
    super.dispose();
  }

  void _startSearch() {
    setState(() => _isSearching = true);
  }

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _clearSearchFilters();
    });
  }

  void _onFilterChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _clearSearchFilters() {
    _searchController.clear();
    _minAmountController.clear();
    _maxAmountController.clear();
    _searchQuery = '';
    _typeFilter = _TransactionTypeFilter.all;
    _dateFilter = _TransactionDateFilter.all;
    _showAmountInputs = false;
  }

  _TransactionSearchState get _searchState {
    return _TransactionSearchState(
      query: _searchQuery,
      typeFilter: _typeFilter,
      dateFilter: _dateFilter,
      minAmount: _parseAmount(_minAmountController.text),
      maxAmount: _parseAmount(_maxAmountController.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final actionColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search merchant, note, tag, category',
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
              icon: Icon(Icons.close, color: actionColor),
            )
          else
            IconButton(
              tooltip: 'Search',
              onPressed: _startSearch,
              icon: Icon(Icons.search, color: actionColor),
            ),
          IconButton(
            tooltip: 'Accounts',
            onPressed: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(builder: (_) => const AccountsScreen()),
            ),
            icon: Icon(
              Icons.account_balance_wallet_outlined,
              color: actionColor,
            ),
          ),
          IconButton(
            tooltip: 'Categories',
            onPressed: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(
                builder: (_) => const CategoryManagementScreen(),
              ),
            ),
            icon: Icon(Icons.category_outlined, color: actionColor),
          ),
          IconButton(
            tooltip: 'Rules',
            onPressed: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(
                builder: (_) => const TransactionRulesScreen(),
              ),
            ),
            icon: Icon(Icons.rule, color: actionColor),
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
            isSearching: _isSearching,
            searchState: _searchState,
            typeFilter: _typeFilter,
            dateFilter: _dateFilter,
            minAmountController: _minAmountController,
            maxAmountController: _maxAmountController,
            showAmountInputs: _showAmountInputs,
            onTypeFilterChanged: (value) => setState(() => _typeFilter = value),
            onDateFilterChanged: (value) => setState(() => _dateFilter = value),
            onToggleAmountInputs: () =>
                setState(() => _showAmountInputs = !_showAmountInputs),
            onClearSearch: () => setState(_clearSearchFilters),
          );
        },
      ),
      bottomNavigationBar: SizedBox(
        height: MediaQuery.paddingOf(context).bottom.clamp(16.0, double.infinity) + 80.0,
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

double? _parseAmount(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return double.tryParse(trimmed);
}

enum _TransactionTypeFilter { all, income, expense, transfer }

enum _TransactionDateFilter { all, last30Days, thisMonth }

class _TransactionSearchState {
  const _TransactionSearchState({
    required this.query,
    required this.typeFilter,
    required this.dateFilter,
    required this.minAmount,
    required this.maxAmount,
  });

  final String query;
  final _TransactionTypeFilter typeFilter;
  final _TransactionDateFilter dateFilter;
  final double? minAmount;
  final double? maxAmount;

  bool get isActive {
    return query.isNotEmpty ||
        typeFilter != _TransactionTypeFilter.all ||
        dateFilter != _TransactionDateFilter.all ||
        minAmount != null ||
        maxAmount != null;
  }
}

class _MonthlyTransactionTabs extends StatelessWidget {
  const _MonthlyTransactionTabs({
    required this.transactions,
    required this.isSearching,
    required this.searchState,
    required this.typeFilter,
    required this.dateFilter,
    required this.minAmountController,
    required this.maxAmountController,
    required this.showAmountInputs,
    required this.onTypeFilterChanged,
    required this.onDateFilterChanged,
    required this.onToggleAmountInputs,
    required this.onClearSearch,
  });

  final List<FinanceTransaction> transactions;
  final bool isSearching;
  final _TransactionSearchState searchState;
  final _TransactionTypeFilter typeFilter;
  final _TransactionDateFilter dateFilter;
  final TextEditingController minAmountController;
  final TextEditingController maxAmountController;
  final bool showAmountInputs;
  final ValueChanged<_TransactionTypeFilter> onTypeFilterChanged;
  final ValueChanged<_TransactionDateFilter> onDateFilterChanged;
  final VoidCallback onToggleAmountInputs;
  final VoidCallback onClearSearch;

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
          if (isSearching)
            _TransactionInlineFilters(
              typeFilter: typeFilter,
              dateFilter: dateFilter,
              minAmountController: minAmountController,
              maxAmountController: maxAmountController,
              showAmountInputs: showAmountInputs,
              onTypeFilterChanged: onTypeFilterChanged,
              onDateFilterChanged: onDateFilterChanged,
              onToggleAmountInputs: onToggleAmountInputs,
              onClearSearch: onClearSearch,
              hasActiveFilters: searchState.isActive,
            ),
          Expanded(
            child: TabBarView(
              children: [
                for (final month in months)
                  _TransactionMonthPage(
                    transactions: _transactionsForMonth(month, transactions),
                    allTransactions: transactions,
                    searchState: searchState,
                    monthLabel: month.label,
                    onClearSearch: onClearSearch,
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

class _TransactionInlineFilters extends StatelessWidget {
  const _TransactionInlineFilters({
    required this.typeFilter,
    required this.dateFilter,
    required this.minAmountController,
    required this.maxAmountController,
    required this.showAmountInputs,
    required this.onTypeFilterChanged,
    required this.onDateFilterChanged,
    required this.onToggleAmountInputs,
    required this.onClearSearch,
    required this.hasActiveFilters,
  });

  final _TransactionTypeFilter typeFilter;
  final _TransactionDateFilter dateFilter;
  final TextEditingController minAmountController;
  final TextEditingController maxAmountController;
  final bool showAmountInputs;
  final ValueChanged<_TransactionTypeFilter> onTypeFilterChanged;
  final ValueChanged<_TransactionDateFilter> onDateFilterChanged;
  final VoidCallback onToggleAmountInputs;
  final VoidCallback onClearSearch;
  final bool hasActiveFilters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  SegmentedButton<_TransactionTypeFilter>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: _TransactionTypeFilter.all,
                        label: Text('All'),
                      ),
                      ButtonSegment(
                        value: _TransactionTypeFilter.income,
                        label: Text('Income'),
                      ),
                      ButtonSegment(
                        value: _TransactionTypeFilter.expense,
                        label: Text('Expense'),
                      ),
                      ButtonSegment(
                        value: _TransactionTypeFilter.transfer,
                        label: Text('Transfer'),
                      ),
                    ],
                    selected: {typeFilter},
                    onSelectionChanged: (value) =>
                        onTypeFilterChanged(value.first),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Amount'),
                    selected: showAmountInputs,
                    onSelected: (_) => onToggleAmountInputs(),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<_TransactionDateFilter>(
                    tooltip: 'Date filter',
                    onSelected: onDateFilterChanged,
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _TransactionDateFilter.all,
                        child: Text('All dates'),
                      ),
                      PopupMenuItem(
                        value: _TransactionDateFilter.thisMonth,
                        child: Text('This month'),
                      ),
                      PopupMenuItem(
                        value: _TransactionDateFilter.last30Days,
                        child: Text('Last 30 days'),
                      ),
                    ],
                    child: Chip(
                      avatar: Icon(
                        Icons.date_range_outlined,
                        size: 18,
                        color: dateFilter == _TransactionDateFilter.all
                            ? AikoColors.mutedText
                            : theme.colorScheme.primary,
                      ),
                      label: Text(_dateFilterLabel(dateFilter)),
                      backgroundColor: dateFilter == _TransactionDateFilter.all
                          ? null
                          : theme.colorScheme.primary.withValues(alpha: 0.12),
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                  ),
                  if (hasActiveFilters) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: onClearSearch,
                      child: const Text('Clear all'),
                    ),
                  ],
                ],
              ),
            ),
            if (showAmountInputs) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minAmountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Min',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: maxAmountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Max',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _dateFilterLabel(_TransactionDateFilter filter) {
  return switch (filter) {
    _TransactionDateFilter.all => 'Date',
    _TransactionDateFilter.thisMonth => 'This month',
    _TransactionDateFilter.last30Days => 'Last 30 days',
  };
}

class _TransactionMonthPage extends ConsumerWidget {
  const _TransactionMonthPage({
    required this.transactions,
    required this.allTransactions,
    required this.searchState,
    required this.monthLabel,
    required this.onClearSearch,
  });

  final List<FinanceTransaction> transactions;
  final List<FinanceTransaction> allTransactions;
  final _TransactionSearchState searchState;
  final String monthLabel;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts =
        ref.watch(accountsProvider).whenOrNull(data: (accounts) => accounts) ??
        const <Account>[];
    final categories =
        ref
            .watch(categoriesProvider)
            .whenOrNull(data: (categories) => categories) ??
        const [];
    final accountsById = {for (final account in accounts) account.id: account};
    final categoriesById = {
      for (final category in categories) category.id: category,
    };

    final filtered = transactions.where((tx) {
      return _matchesSearchState(
        transaction: tx,
        searchState: searchState,
        account: accountsById[tx.accountId],
        categoryName: categoriesById[tx.categoryId]?.name,
      );
    }).toList()..sort((a, b) => b.date.compareTo(a.date));

    if (filtered.isEmpty) {
      return AikoScreenState.empty(
        title: searchState.isActive
            ? 'No matching transactions'
            : 'No transactions in $monthLabel',
        message: searchState.isActive
            ? 'Try a different search or clear filters.'
            : 'Add a transaction for this month when you are ready.',
        action: searchState.isActive
            ? TextButton(
                onPressed: onClearSearch,
                child: const Text('Clear search'),
              )
            : null,
      );
    }

    final groups = _groupTransactionsByDate(filtered);
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

  bool _matchesSearchState({
    required FinanceTransaction transaction,
    required _TransactionSearchState searchState,
    required Account? account,
    required String? categoryName,
  }) {
    if (!_matchesType(transaction, searchState.typeFilter)) {
      return false;
    }
    if (!_matchesDate(transaction.date, searchState.dateFilter)) {
      return false;
    }
    final amount = transaction.amount.amount.toDouble().abs();
    if (searchState.minAmount != null && amount < searchState.minAmount!) {
      return false;
    }
    if (searchState.maxAmount != null && amount > searchState.maxAmount!) {
      return false;
    }

    final query = searchState.query.toLowerCase();
    if (query.isEmpty) {
      return true;
    }

    final searchableText = [
      transaction.merchant,
      transaction.note,
      categoryName,
      account?.name,
      transaction.amount.amount.toString(),
      transaction.amount.format(),
      transaction.type.name,
      ...transaction.tags,
    ].whereType<String>().join(' ').toLowerCase();

    return searchableText.contains(query);
  }

  bool _matchesType(
    FinanceTransaction transaction,
    _TransactionTypeFilter filter,
  ) {
    return switch (filter) {
      _TransactionTypeFilter.all => true,
      _TransactionTypeFilter.income =>
        transaction.type == TransactionType.income,
      _TransactionTypeFilter.expense =>
        transaction.type == TransactionType.expense,
      _TransactionTypeFilter.transfer =>
        transaction.type == TransactionType.transfer,
    };
  }

  bool _matchesDate(DateTime date, _TransactionDateFilter filter) {
    final today = _dateOnly(DateTime.now());
    final currentMonth = DateTime(today.year, today.month);
    return switch (filter) {
      _TransactionDateFilter.all => true,
      _TransactionDateFilter.thisMonth => !date.isBefore(currentMonth),
      _TransactionDateFilter.last30Days => !date.isBefore(
        today.subtract(const Duration(days: 30)),
      ),
    };
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
    for (final account in accounts) account.id: account.currentBalance,
  };
  final visibleIds = transactions.map((transaction) => transaction.id).toSet();
  final labels = <String, String>{};
  final sorted = [...allTransactions]..sort((a, b) => b.date.compareTo(a.date));

  for (final transaction in sorted) {
    final account = accountsById[transaction.accountId];
    final balanceAfterTransaction = balancesByAccountId[transaction.accountId];
    if (balanceAfterTransaction == null) {
      continue;
    }

    if (account != null && visibleIds.contains(transaction.id)) {
      labels[transaction.id] =
          '${account.name} (${balanceAfterTransaction.format()})';
    }

    balancesByAccountId[transaction.accountId] = transaction
        .reverseFromAccountBalance(balanceAfterTransaction);
  }

  return labels;
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
    final timeLabel = DateFormat('HH:mm').format(transaction.date);
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
                    const SizedBox(height: 3),
                    _TransactionTimeAndTags(
                      time: timeLabel,
                      tags: transaction.tags,
                    ),
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

class _TransactionTimeAndTags extends StatelessWidget {
  const _TransactionTimeAndTags({required this.time, required this.tags});

  final String time;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 4,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              time,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AikoColors.mutedText),
            ),
            for (final tag in tags) _TransactionTagChip(label: '#$tag'),
          ],
        );
      },
    );
  }
}

class _TransactionTagChip extends StatelessWidget {
  const _TransactionTagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AikoColors.mutedText,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
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
