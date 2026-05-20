import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/money/money.dart';
import '../../../shared/test_data/demo_data.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';
import '../../budgets/presentation/budget_form_screen.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/transaction_form_screen.dart';
import 'widgets/calculator_shortcuts_widget.dart';
import 'widgets/dashboard_due_items_widget.dart';

class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);

    var monthlyIncomeVal = DemoData.monthlyIncome.amount;
    var monthlySpendingVal = DemoData.monthlySpending.amount;
    var safeToSpendVal = DemoData.safeToSpend.amount;

    if (transactionsAsync.hasValue) {
      final transactions = transactionsAsync.value!;
      final now = DateTime.now();
      final currentMonthTransactions = transactions
          .where((tx) => tx.date.year == now.year && tx.date.month == now.month)
          .toList();

      if (currentMonthTransactions.isNotEmpty) {
        var income = Decimal.zero;
        var spending = Decimal.zero;
        for (final tx in currentMonthTransactions) {
          if (tx.type == TransactionType.income) {
            income += tx.amount.amount;
          } else if (tx.type == TransactionType.expense) {
            spending += tx.amount.amount;
          }
        }
        monthlyIncomeVal = income;
        monthlySpendingVal = spending;

        // Weekly balance of income minus spending, kept in Decimal.
        final weeklyFlow = ((income - spending) / Decimal.parse('4.33'))
            .toDecimal(scaleOnInfinitePrecision: 2);
        safeToSpendVal = weeklyFlow > Decimal.zero
            ? weeklyFlow
            : DemoData.safeToSpend.amount;
      }
    }

    final monthlyIncome = Money(amount: monthlyIncomeVal, currency: 'USD');
    final monthlySpending = Money(amount: monthlySpendingVal, currency: 'USD');
    final safeToSpend = Money(amount: safeToSpendVal, currency: 'USD');

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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: [
          FinanceCard(
            title: 'Hi, I am Aiko',
            icon: Icons.auto_awesome,
            accentColor: AikoColors.premiumPurple,
            prominent: true,
            child: Text(
              'You still have ${safeToSpend.format()} safe to spend this week. This is an estimate, so keep bills and planned purchases in view.',
            ),
          ),
          const SizedBox(height: 16),
          FinanceCard(
            title: 'Safe to spend',
            icon: Icons.savings_outlined,
            prominent: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AmountText(safeToSpend.format()),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: const LinearProgressIndicator(value: 0.68),
                ),
                const SizedBox(height: 8),
                Text(
                  'Weekly cushion after recurring commitments.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FinanceCard(
            title: 'Monthly cash flow',
            icon: Icons.trending_up,
            accentColor: AikoColors.analyticsTeal,
            child: Column(
              children: [
                _MetricLine(
                  label: 'Income',
                  value: monthlyIncome.format(),
                  color: AikoColors.successGreen,
                ),
                const SizedBox(height: 8),
                _MetricLine(
                  label: 'Spending',
                  value: monthlySpending.format(),
                  color: AikoColors.warningOrange,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const FinanceCard(
            title: 'Pace',
            icon: Icons.speed,
            accentColor: AikoColors.deepBlue,
            child: Text('On track. Keep flexible spending under 35 USD/day.'),
          ),
          const SizedBox(height: 16),
          const DashboardDueItemsWidget(items: []),
          const SizedBox(height: 16),
          const FinanceCard(
            title: 'Recent transactions',
            icon: Icons.receipt_long,
            child: Text('Coffee, Groceries, Salary, Transit'),
          ),
          const SizedBox(height: 16),
          const CalculatorShortcutsWidget(),
        ],
      ),
      floatingActionButton: const _QuickAddMenu(),
    );
  }
}

class _QuickAddMenu extends StatefulWidget {
  const _QuickAddMenu();

  @override
  State<_QuickAddMenu> createState() => _QuickAddMenuState();
}

class _QuickAddMenuState extends State<_QuickAddMenu> {
  var _isOpen = false;

  void _toggle() {
    setState(() => _isOpen = !_isOpen);
  }

  void _openAddPage(Widget page) {
    setState(() => _isOpen = false);
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: _isOpen
              ? Column(
                  key: const ValueKey('quick-add-options'),
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _QuickAddOption(
                      heroTag: 'quick-add-transaction',
                      icon: Icons.receipt_long_outlined,
                      label: 'Transaction',
                      onPressed: () =>
                          _openAddPage(const TransactionFormScreen()),
                    ),
                    const SizedBox(height: 8),
                    _QuickAddOption(
                      heroTag: 'quick-add-budget',
                      icon: Icons.pie_chart_outline,
                      label: 'Budget',
                      onPressed: () => _openAddPage(const BudgetFormScreen()),
                    ),
                    const SizedBox(height: 12),
                  ],
                )
              : const SizedBox.shrink(key: ValueKey('quick-add-empty')),
        ),
        FloatingActionButton.extended(
          heroTag: 'quick-add-main',
          onPressed: _toggle,
          icon: Icon(_isOpen ? Icons.close : Icons.add),
          label: Text(_isOpen ? 'Close' : 'Quick add'),
        ),
      ],
    );
  }
}

class _QuickAddOption extends StatelessWidget {
  const _QuickAddOption({
    required this.heroTag,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final String heroTag;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: heroTag,
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        Text(value, style: theme.textTheme.titleSmall),
      ],
    );
  }
}
