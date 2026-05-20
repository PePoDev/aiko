import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/money/money.dart';
import '../../transactions/domain/transaction.dart';
import '../../../shared/test_data/demo_data.dart';
import '../../../shared/widgets/finance_card.dart';
import 'widgets/calculator_shortcuts_widget.dart';
import 'widgets/dashboard_due_items_widget.dart';

class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);

    // Dynamic calculations from live transactions
    var monthlyIncomeVal = DemoData.monthlyIncome.amount;
    var monthlySpendingVal = DemoData.monthlySpending.amount;
    var safeToSpendVal = DemoData.safeToSpend.amount;

    if (transactionsAsync.hasValue) {
      final transactions = transactionsAsync.value!;
      final now = DateTime.now();
      final currentMonthTransactions = transactions.where((tx) =>
        tx.date.year == now.year && tx.date.month == now.month
      ).toList();

      if (currentMonthTransactions.isNotEmpty) {
        double income = 0;
        double spending = 0;
        for (final tx in currentMonthTransactions) {
          if (tx.type == TransactionType.income) {
            income += tx.amount.amount;
          } else if (tx.type == TransactionType.expense) {
            spending += tx.amount.amount;
          }
        }
        monthlyIncomeVal = income;
        monthlySpendingVal = spending;

        // Calculate safe to spend weekly: weekly balance of (income - spending)
        final weeklyFlow = (income - spending) / 4.33;
        safeToSpendVal = weeklyFlow > 0 ? weeklyFlow : DemoData.safeToSpend.amount;
      }
    }

    final monthlyIncome = Money(monthlyIncomeVal, 'USD');
    final monthlySpending = Money(monthlySpendingVal, 'USD');
    final safeToSpend = Money(safeToSpendVal, 'USD');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FinanceCard(
            title: 'Hi, I am Aiko',
            icon: Icons.auto_awesome,
            child: Text(
              'You still have ${safeToSpend.format()} safe to spend this week.',
            ),
          ),
          const SizedBox(height: 12),
          FinanceCard(
            title: 'Safe to spend',
            icon: Icons.savings_outlined,
            child: AmountText(safeToSpend.format()),
          ),
          const SizedBox(height: 12),
          FinanceCard(
            title: 'Monthly cash flow',
            icon: Icons.trending_up,
            child: Text(
              'Income ${monthlyIncome.format()} • Spending ${monthlySpending.format()}',
            ),
          ),
          const SizedBox(height: 12),
          const FinanceCard(
            title: 'Pace',
            icon: Icons.speed,
            child: Text('On track. Keep flexible spending under 35 USD/day.'),
          ),
          const SizedBox(height: 12),
          const DashboardDueItemsWidget(items: []),
          const SizedBox(height: 12),
          const FinanceCard(
            title: 'Recent transactions',
            icon: Icons.receipt_long,
            child: Text('Coffee, Groceries, Salary, Transit'),
          ),
          const SizedBox(height: 12),
          const CalculatorShortcutsWidget(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/transactions'),
        icon: const Icon(Icons.add),
        label: const Text('Quick add'),
      ),
    );
  }
}
