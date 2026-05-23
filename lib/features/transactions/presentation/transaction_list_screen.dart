import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/screen_states.dart';
import '../../../theme/aiko_colors.dart';
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
            tooltip: 'Rules',
            onPressed: () => Navigator.of(context).push(
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const TransactionFormScreen(),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
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

class _TransactionMonthPage extends StatelessWidget {
  const _TransactionMonthPage({
    required this.transactions,
    required this.searchQuery,
    required this.monthLabel,
  });

  final List<FinanceTransaction> transactions;
  final String searchQuery;
  final String monthLabel;

  @override
  Widget build(BuildContext context) {
    final filtered = transactions.where((tx) {
      if (searchQuery.isEmpty) return true;
      final query = searchQuery.toLowerCase();
      return (tx.merchant ?? '').toLowerCase().contains(query) ||
          (tx.note ?? '').toLowerCase().contains(query);
    }).toList();

    if (filtered.isEmpty) {
      return AikoScreenState.empty(
        title: 'No transactions in $monthLabel',
        message: searchQuery.isEmpty
            ? 'Add a transaction for this month when you are ready.'
            : 'Try another search, or switch to another month.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final tx = filtered[index];
        final sign = tx.type == TransactionType.income ? '+' : '-';
        final accent = tx.type == TransactionType.income
            ? AikoColors.successGreen
            : AikoColors.dangerRed;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _CompactTransactionCard(
            transaction: tx,
            accent: accent,
            sign: sign,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TransactionDetailScreen(transaction: tx),
              ),
            ),
          ),
        );
      },
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
    required this.accent,
    required this.sign,
    required this.onTap,
  });

  final FinanceTransaction transaction;
  final Color accent;
  final String sign;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = transaction.merchant ?? transaction.note ?? 'Transaction';
    final amount = '$sign\$${transaction.amount.amount.toStringAsFixed(2)}';
    final icon = transaction.type == TransactionType.income
        ? Icons.south_west
        : Icons.north_east;

    final accountsAsync = ref.watch(accountsProvider);
    final accountName =
        accountsAsync.whenOrNull(
          data: (accounts) {
            for (final account in accounts) {
              if (account.id == transaction.accountId) {
                return account.name;
              }
            }
            return 'Unknown';
          },
        ) ??
        'Unknown';

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
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
                child: Icon(icon, color: accent, size: 16),
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
                    const SizedBox(height: 2),
                    Text(
                      '$accountName • ${transaction.type.name.toUpperCase()} • ${transaction.date.toString().substring(0, 10)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                amount,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
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
}
