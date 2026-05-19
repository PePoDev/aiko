import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/test_data/demo_data.dart';
import '../../../shared/widgets/finance_card.dart';
import 'widgets/calculator_shortcuts_widget.dart';
import 'widgets/dashboard_due_items_widget.dart';

class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.go('/settings'),
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
              'You still have ${DemoData.safeToSpend.format()} safe to spend this week.',
            ),
          ),
          const SizedBox(height: 12),
          FinanceCard(
            title: 'Safe to spend',
            icon: Icons.savings_outlined,
            child: AmountText(DemoData.safeToSpend.format()),
          ),
          const SizedBox(height: 12),
          FinanceCard(
            title: 'Monthly cash flow',
            icon: Icons.trending_up,
            child: Text(
              'Income ${DemoData.monthlyIncome.format()} • Spending ${DemoData.monthlySpending.format()}',
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
