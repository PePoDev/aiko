import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/finance_card.dart';
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
                    final title =
                        '${tx.merchant ?? tx.note ?? 'Transaction'} $sign\$${tx.amount.amount.toStringAsFixed(2)}';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: FinanceCard(
                        title: title,
                        icon: tx.type == TransactionType.income
                            ? Icons.south_west
                            : Icons.north_east,
                        accentColor: accent,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                TransactionDetailScreen(transaction: tx),
                          ),
                        ),
                        child: Text(
                          '${tx.type.name.toUpperCase()} - ${tx.date.toString().substring(0, 10)}',
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
