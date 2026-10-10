import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/money/money.dart';
import '../../../l10n/domain_labels.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/layout/adaptive_presentation.dart';
import '../../../shared/layout/aiko_breakpoints.dart';
import '../../../shared/widgets/screen_states.dart';
import '../../../theme/aiko_colors.dart';
import '../../accounts/domain/account.dart';
import '../../categories/presentation/category_names.dart';
import '../../categories/presentation/category_visual.dart';
import '../application/recurring_projection.dart';
import '../application/transaction_month_range.dart';
import '../domain/transaction.dart';
import 'transaction_detail_screen.dart';
import 'transaction_form_screen.dart';

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
        title: Text(context.l10n.transactionsTab),
        actions: [
          if (_isSearching)
            IconButton(
              tooltip: context.l10n.txCloseSearch,
              onPressed: _stopSearch,
              icon: Icon(Icons.close, color: actionColor),
            )
          else
            IconButton(
              tooltip: context.l10n.txSearch,
              onPressed: _startSearch,
              icon: Icon(Icons.search, color: actionColor),
            ),
          IconButton(
            tooltip: context.l10n.txRules,
            onPressed: () => context.push('/transaction-rules'),
            icon: Icon(Icons.rule, color: actionColor),
          ),
          IconButton(
            tooltip: context.l10n.txTravelMode,
            onPressed: () => context.push('/travel-mode'),
            icon: Icon(Icons.flight_takeoff_outlined, color: actionColor),
          ),
        ],
      ),
      body: transactionsAsync.when(
        loading: () => const AikoScreenState.loading(),
        error: (err, stack) => AikoScreenState.error(
          title: context.l10n.txListUnavailableTitle,
          message: context.l10n.txListUnavailableMessage,
        ),
        data: (transactions) {
          return _MonthlyTransactionTabs(
            transactions: transactions,
            isSearching: _isSearching,
            searchController: _searchController,
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
      // Wide layouts add transactions from the sidebar instead.
      floatingActionButton: AikoBreakpoints.isExpanded(context)
          ? null
          : FloatingActionButton(
              onPressed: () => openAikoPage<void>(
                context,
                const TransactionFormScreen(),
                rootNavigator: true,
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
    required this.searchController,
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
  final TextEditingController searchController;
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
    final now = DateTime.now();
    final currentMonth = TransactionMonth.fromDate(now);
    final months = const TransactionMonthRangeService().monthsFor(
      transactions: transactions,
      currentDate: now,
    );
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
              tabs: [for (final month in months) Tab(text: _monthLabel(month))],
            ),
          ),
          if (isSearching) ...[
            _TransactionSearchField(controller: searchController),
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
          ],
          Expanded(
            child: TabBarView(
              children: [
                for (final month in months)
                  _TransactionMonthPage(
                    transactions: _transactionsForMonth(month, transactions),
                    allTransactions: transactions,
                    searchState: searchState,
                    month: month,
                    onClearSearch: onClearSearch,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static List<FinanceTransaction> _transactionsForMonth(
    TransactionMonth month,
    List<FinanceTransaction> transactions,
  ) {
    return transactions
        .where(
          (transaction) => TransactionMonth.fromDate(transaction.date) == month,
        )
        .toList(growable: false);
  }
}

class _TransactionSearchField extends StatelessWidget {
  const _TransactionSearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: TextField(
          controller: controller,
          autofocus: true,
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            hintText: context.l10n.txSearchHint,
            prefixIcon: Icon(Icons.search),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
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
                    segments: [
                      ButtonSegment(
                        value: _TransactionTypeFilter.all,
                        label: Text(context.l10n.txFilterAll),
                      ),
                      ButtonSegment(
                        value: _TransactionTypeFilter.income,
                        label: Text(context.l10n.transactionTypeIncome),
                      ),
                      ButtonSegment(
                        value: _TransactionTypeFilter.expense,
                        label: Text(context.l10n.transactionTypeExpense),
                      ),
                      ButtonSegment(
                        value: _TransactionTypeFilter.transfer,
                        label: Text(context.l10n.transactionTypeTransfer),
                      ),
                    ],
                    selected: {typeFilter},
                    onSelectionChanged: (value) =>
                        onTypeFilterChanged(value.first),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text(context.l10n.txAmount),
                    selected: showAmountInputs,
                    onSelected: (_) => onToggleAmountInputs(),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<_TransactionDateFilter>(
                    tooltip: context.l10n.txDateFilterTooltip,
                    onSelected: onDateFilterChanged,
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: _TransactionDateFilter.all,
                        child: Text(context.l10n.txFilterAllDates),
                      ),
                      PopupMenuItem(
                        value: _TransactionDateFilter.thisMonth,
                        child: Text(context.l10n.txFilterThisMonth),
                      ),
                      PopupMenuItem(
                        value: _TransactionDateFilter.last30Days,
                        child: Text(context.l10n.txFilterLast30Days),
                      ),
                    ],
                    child: Chip(
                      avatar: Icon(
                        Icons.date_range_outlined,
                        size: 18,
                        color: dateFilter == _TransactionDateFilter.all
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.primary,
                      ),
                      label: Text(_dateFilterLabel(dateFilter, context.l10n)),
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
                      child: Text(context.l10n.txClearAll),
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
                      decoration: InputDecoration(
                        labelText: context.l10n.txMin,
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
                      decoration: InputDecoration(
                        labelText: context.l10n.txMax,
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

String _dateFilterLabel(_TransactionDateFilter filter, AppLocalizations l10n) {
  return switch (filter) {
    _TransactionDateFilter.all => l10n.txFilterDate,
    _TransactionDateFilter.thisMonth => l10n.txFilterThisMonth,
    _TransactionDateFilter.last30Days => l10n.txFilterLast30Days,
  };
}

class _TransactionMonthPage extends ConsumerStatefulWidget {
  const _TransactionMonthPage({
    required this.transactions,
    required this.allTransactions,
    required this.searchState,
    required this.month,
    required this.onClearSearch,
  });

  final List<FinanceTransaction> transactions;
  final List<FinanceTransaction> allTransactions;
  final _TransactionSearchState searchState;
  final TransactionMonth month;
  final VoidCallback onClearSearch;

  @override
  ConsumerState<_TransactionMonthPage> createState() =>
      _TransactionMonthPageState();
}

class _TransactionMonthPageState extends ConsumerState<_TransactionMonthPage> {
  @override
  Widget build(BuildContext context) {
    final searchState = widget.searchState;
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

    final filtered = widget.transactions.where((tx) {
      return _matchesSearchState(
        transaction: tx,
        searchState: searchState,
        account: accountsById[tx.accountId],
        categoryName: categoriesById[tx.categoryId]?.displayName(context.l10n),
      );
    }).toList()..sort((a, b) => b.date.compareTo(a.date));

    // Display-only previews of recurring series falling in this month. Hidden
    // while searching (they aren't real records to match against).
    final ghosts = <FinanceTransaction>[];
    final previewSources = <String, FinanceTransaction>{};
    if (!searchState.isActive) {
      const projection = RecurringProjection();
      for (final tx in widget.allTransactions) {
        for (final ghost in projection.occurrencesInMonth(
          tx,
          widget.month.year,
          widget.month.month,
        )) {
          ghosts.add(ghost);
          previewSources[ghost.id] = tx;
        }
      }
    }
    final previewIds = previewSources.keys.toSet();

    if (filtered.isEmpty && ghosts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            AikoScreenState.empty(
              title: searchState.isActive
                  ? context.l10n.txNoMatching
                  : context.l10n.txNoneInMonth(_monthLabel(widget.month)),
              message: searchState.isActive
                  ? context.l10n.txNoMatchingHint
                  : context.l10n.txNoneInMonthHint,
              action: searchState.isActive
                  ? TextButton(
                      onPressed: widget.onClearSearch,
                      child: Text(context.l10n.txClearSearch),
                    )
                  : null,
            ),
          ],
        ),
      );
    }

    final groups = _groupTransactionsByDate([
      ...filtered,
      ...ghosts,
    ], previewIds);
    final accountLabels = _accountLabelsForTransactions(
      transactions: filtered,
      allTransactions: widget.allTransactions,
      accounts: accounts,
    );
    for (final ghost in ghosts) {
      accountLabels[ghost.id] =
          accountsById[ghost.accountId]?.name ?? context.l10n.txUpcoming;
    }

    final monthTotal = _monthTotal(filtered);
    final daysInMonth = DateTime(
      widget.month.year,
      widget.month.month + 1,
      0,
    ).day;
    final averagePerDay = Money(
      amount: (monthTotal.amount / Decimal.fromInt(daysInMonth)).toDecimal(
        scaleOnInfinitePrecision: 2,
      ),
      currency: monthTotal.currency,
    );

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
        children: [
          _MonthSummaryCard(
            monthLabel: _monthLabel(widget.month),
            total: monthTotal,
            averagePerDay: averagePerDay,
            onTap: () => context.push('/reports/monthly'),
          ),
          const SizedBox(height: 16),
          for (final group in groups) ...[
            _TransactionDateHeader(date: group.date, total: group.total),
            _DayTransactionsCard(
              transactions: group.transactions,
              accountLabels: accountLabels,
              previewIds: previewIds,
              previewSources: previewSources,
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Future<void> _refresh() async {
    await Future.wait([
      ref.refresh(transactionsProvider.future),
      ref.refresh(accountsProvider.future),
      ref.refresh(categoriesProvider.future),
    ]);
  }

  Money _monthTotal(List<FinanceTransaction> transactions) =>
      _dailyTotal(transactions);

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
      transaction.type.label(context.l10n),
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
        transaction.type == TransactionType.transfer ||
            transaction.type == TransactionType.transferIn ||
            transaction.type == TransactionType.transferOut,
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
    Set<String> previewIds,
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
          // Preview rows are projections, not money that moved — keep them out
          // of the day total.
          total: _dailyTotal(
            grouped[date]!
                .where((t) => !previewIds.contains(t.id))
                .toList(growable: false),
          ),
        ),
    ];
  }

  Money _dailyTotal(List<FinanceTransaction> transactions) {
    if (transactions.isEmpty) {
      return Money.zero('USD');
    }
    final currency = transactions.first.amount.currency;
    var amount = Decimal.zero;
    for (final transaction in transactions) {
      if (transaction.amount.currency != currency) {
        continue;
      }
      if (transaction.type == TransactionType.income) {
        amount += transaction.amount.amount;
      } else {
        amount -= transaction.amount.amount;
      }
    }
    return Money(amount: amount, currency: currency);
  }
}

class _TransactionDateGroup {
  const _TransactionDateGroup({
    required this.date,
    required this.transactions,
    required this.total,
  });

  final DateTime date;
  final List<FinanceTransaction> transactions;
  final Money total;
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
  const _TransactionDateHeader({required this.date, required this.total});

  final DateTime date;
  final Money total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.titleSmall?.copyWith(
      color: theme.colorScheme.onSurface,
      fontWeight: FontWeight.w700,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(_dateHeaderLabel(date, context.l10n), style: headerStyle),
          const Spacer(),
          Text(
            _formatDailyTotal(total),
            style: headerStyle?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Month spending summary shown above the day groups. Mirrors the daily-total
/// math (`income +`, everything else `−`) so the headline matches the rows.
class _MonthSummaryCard extends StatelessWidget {
  const _MonthSummaryCard({
    required this.monthLabel,
    required this.total,
    required this.averagePerDay,
    required this.onTap,
  });

  final String monthLabel;
  final Money total;
  final Money averagePerDay;
  final VoidCallback onTap;

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
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.txMonthSummary(monthLabel),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _MonthSummaryMetric(
                            label: context.l10n.txTotalSpent,
                            value: _formatDailyTotal(total),
                            valueColor: AikoColors.dangerRed,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 32,
                          color: theme.colorScheme.outlineVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MonthSummaryMetric(
                            label: context.l10n.txAveragePerDay,
                            value: _formatDailyTotal(averagePerDay),
                            valueColor: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
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
}

class _MonthSummaryMetric extends StatelessWidget {
  const _MonthSummaryMetric({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// One card per day holding that day's transaction rows, divided by hairlines —
/// matches the grouped-card layout in the design.
class _DayTransactionsCard extends StatelessWidget {
  const _DayTransactionsCard({
    required this.transactions,
    required this.accountLabels,
    required this.previewIds,
    required this.previewSources,
  });

  final List<FinanceTransaction> transactions;
  final Map<String, String> accountLabels;
  final Set<String> previewIds;
  final Map<String, FinanceTransaction> previewSources;

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
          for (var i = 0; i < transactions.length; i++) ...[
            if (i != 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: 16,
                endIndent: 16,
                color: theme.colorScheme.outlineVariant,
              ),
            _TransactionRow(
              transaction: transactions[i],
              accountLabel:
                  accountLabels[transactions[i].id] ??
                  context.l10n.txUnknownAccount,
              accent: transactions[i].type == TransactionType.income
                  ? AikoColors.successGreen
                  : AikoColors.dangerRed,
              sign: transactions[i].type == TransactionType.income ? '+' : '-',
              isPreview: previewIds.contains(transactions[i].id),
              // Preview rows open their source recurring transaction so the
              // user can edit the series; real rows open themselves.
              onTap: () => openAikoPage<void>(
                context,
                TransactionDetailScreen(
                  transaction:
                      previewSources[transactions[i].id] ?? transactions[i],
                ),
                rootNavigator: true,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Oct 2026" / "ต.ค. 2026" in the current language.
String _monthLabel(TransactionMonth month) {
  return DateFormat.yMMM().format(DateTime(month.year, month.month));
}

class _TransactionRow extends ConsumerWidget {
  const _TransactionRow({
    required this.transaction,
    required this.accountLabel,
    required this.accent,
    required this.sign,
    required this.onTap,
    this.isPreview = false,
  });

  final FinanceTransaction transaction;
  final String accountLabel;
  final Color accent;
  final String sign;
  final VoidCallback onTap;

  /// Projected (not-yet-real) occurrence of a recurring series.
  final bool isPreview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final title =
        transaction.merchant ?? transaction.note ?? context.l10n.txUntitled;
    final amount = '$sign${transaction.amount.format()}';
    final timeLabel = DateFormat('HH:mm').format(transaction.date);
    final categoriesAsync = ref.watch(categoriesProvider);
    final category = categoriesAsync.whenOrNull(
      data: (categories) {
        final matches = categories.where(
          (category) => category.id == transaction.categoryId,
        );
        return matches.isEmpty ? null : matches.first;
      },
    );
    final categoryIcon = category != null
        ? aikoCategoryIcon(category.icon)
        : (transaction.type == TransactionType.income
              ? Icons.south_west
              : Icons.north_east);
    // Tint the icon tile with the category's own color (falling back to the
    // semantic accent for uncategorized rows).
    final iconColor = category != null ? aikoHexColor(category.color) : accent;

    final row = InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(categoryIcon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      if (transaction.isRecurring) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.repeat,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                      if (transaction.splits.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.call_split,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                      if (isPreview) ...[
                        const SizedBox(width: 6),
                        const _UpcomingPill(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  _TransactionMeta(
                    time: timeLabel,
                    categoryName: category?.displayName(context.l10n),
                    status: transaction.status,
                    tags: transaction.tags,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    amount,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    accountLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // Dim previews so they read as "not yet real" against the posted rows.
    return isPreview ? Opacity(opacity: 0.6, child: row) : row;
  }
}

/// Small badge marking a projected (not-yet-created) recurring occurrence.
class _UpcomingPill extends StatelessWidget {
  const _UpcomingPill();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          context.l10n.txUpcoming,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _TransactionMeta extends StatelessWidget {
  const _TransactionMeta({
    required this.time,
    required this.categoryName,
    required this.status,
    required this.tags,
  });

  final String time;
  final String? categoryName;
  final TransactionStatus status;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metaStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          time,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: metaStyle,
        ),
        if (categoryName != null) ...[
          Text('·', style: metaStyle),
          Text(
            categoryName!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: metaStyle,
          ),
        ],
        if (status != TransactionStatus.posted) _StatusPill(status: status),
        for (final tag in tags) _TransactionTagChip(label: '#$tag'),
      ],
    );
  }
}

/// Small semantic pill shown when a transaction isn't `posted` yet.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final TransactionStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      TransactionStatus.draft => (
        context.l10n.txStatusDraft,
        AikoColors.warningOrange,
      ),
      TransactionStatus.voided => (
        context.l10n.txStatusVoided,
        AikoColors.dangerRed,
      ),
      TransactionStatus.archived => (
        context.l10n.txStatusArchived,
        Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      TransactionStatus.posted => (
        context.l10n.txStatusPosted,
        Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
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
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

String _dateHeaderLabel(DateTime date, AppLocalizations l10n) {
  final today = _dateOnly(DateTime.now());
  if (date == today) {
    return l10n.today;
  }
  if (date == today.subtract(const Duration(days: 1))) {
    return l10n.yesterday;
  }
  return DateFormat('EEE, MMM d, yyyy').format(date);
}

String _formatDailyTotal(Money total) {
  final isNegative = total.isNegative;
  final absAmount = total.amount.abs();
  final symbol = NumberFormat.simpleCurrency(
    name: total.currency,
  ).currencySymbol;
  final formatter = NumberFormat.decimalPattern();
  final formatted = formatter.format(absAmount.toDouble());
  final sign = isNegative ? '-' : '';
  return '$sign$symbol$formatted';
}
