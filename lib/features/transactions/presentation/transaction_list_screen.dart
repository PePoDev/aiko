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

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Search transactions',
              ),
            ),
          ),
          Expanded(
            child: transactionsAsync.when(
              loading: () => const AikoScreenState.loading(),
              error: (err, stack) => AikoScreenState.error(
                title: 'Transactions are unavailable',
                message: 'Aiko could not load this list right now. $err',
              ),
              data: (transactions) {
                final filtered = transactions.where((tx) {
                  if (_searchQuery.isEmpty) return true;
                  final query = _searchQuery.toLowerCase();
                  return (tx.merchant ?? '').toLowerCase().contains(query) ||
                      (tx.note ?? '').toLowerCase().contains(query);
                }).toList();

                if (filtered.isEmpty) {
                  return const AikoScreenState.empty(
                    title: 'No transactions found',
                    message:
                        'Try another search, or add your first money move.',
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
                        : AikoColors.deepBlue;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _CompactTransactionCard(
                        transaction: tx,
                        accent: accent,
                        sign: sign,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                TransactionDetailScreen(transaction: tx),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
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

class _CompactTransactionCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final title = transaction.merchant ?? transaction.note ?? 'Transaction';
    final amount = '$sign\$${transaction.amount.amount.toStringAsFixed(2)}';
    final icon = transaction.type == TransactionType.income
        ? Icons.south_west
        : Icons.north_east;

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
                      '${transaction.type.name.toUpperCase()} - ${transaction.date.toString().substring(0, 10)}',
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
