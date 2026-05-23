import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/money/money.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../shared/widgets/screen_states.dart';
import '../../../theme/aiko_colors.dart';
import '../../budgets/presentation/budget_form_screen.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/transaction_form_screen.dart';
import '../domain/dashboard_summary.dart';
import 'widgets/calculator_shortcuts_widget.dart';
import 'widgets/dashboard_due_items_widget.dart';

class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final transactionsAsync = ref.watch(transactionsProvider);
    final dueItemsAsync = ref.watch(dashboardDueItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Overview'),
        actions: [
          IconButton(
            tooltip: 'Aiko Hub',
            onPressed: () => context.push('/more'),
            icon: const Icon(Icons.grid_view_outlined),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: summaryAsync.when(
          loading: () => [const AikoScreenState.loading()],
          error: (error, stack) => [
            AikoScreenState.error(
              title: 'Dashboard is unavailable',
              message: 'Aiko could not load your Supabase workspace.',
            ),
          ],
          data: (summary) => [
            FinanceCard(
              title: 'Hi, I am Aiko',
              icon: Icons.auto_awesome,
              accentColor: AikoColors.premiumPurple,
              prominent: true,
              child: Text(
                'You have ${summary.safeToSpend.format()} estimated safe to spend this week. This is an estimate, so keep bills and planned purchases in view.',
              ),
            ),
            const SizedBox(height: 16),
            FinanceCard(
              title: 'Explore Aiko',
              icon: Icons.apps_outlined,
              accentColor: AikoColors.deepBlue,
              onTap: () => context.go('/more'),
              child: const Text(
                'Open accounts, bills, goals, reports, portfolio, tax, learning, settings, and more.',
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
                  AmountText(summary.safeToSpend.format()),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _safeToSpendProgress(summary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Weekly cushion calculated from your posted transactions.',
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
                    value: summary.monthlyIncome.format(),
                    color: AikoColors.successGreen,
                  ),
                  const SizedBox(height: 8),
                  _MetricLine(
                    label: 'Spending',
                    value: summary.monthlySpending.format(),
                    color: AikoColors.warningOrange,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FinanceCard(
              title: 'Pace',
              icon: Icons.speed,
              accentColor: AikoColors.deepBlue,
              child: Text(
                summary.paceStatus.isFast
                    ? 'Spending is ahead of the current budget pace.'
                    : 'Spending is on pace for the current budget period.',
              ),
            ),
            const SizedBox(height: 16),
            dueItemsAsync.when(
              loading: () => const FinanceCard(
                title: 'Upcoming due dates',
                icon: Icons.event_available_outlined,
                child: Text('Loading bills and card payments...'),
              ),
              error: (error, stack) => const FinanceCard(
                title: 'Upcoming due dates',
                icon: Icons.event_available_outlined,
                child: Text('Unable to load due dates right now.'),
              ),
              data: (items) => DashboardDueItemsWidget(items: items),
            ),
            const SizedBox(height: 16),
            _RecentTransactionsCard(transactionsAsync: transactionsAsync),
            const SizedBox(height: 16),
            const CalculatorShortcutsWidget(),
          ],
        ),
      ),
      floatingActionButton: const _QuickAddMenu(),
    );
  }

  double _safeToSpendProgress(DashboardSummary summary) {
    if (summary.monthlyIncome.amount <=
        Money.zero(summary.monthlyIncome.currency).amount) {
      return 0;
    }
    final value =
        summary.safeToSpend.amount.toDouble() /
        summary.monthlyIncome.amount.toDouble();
    return value.clamp(0.0, 1.0);
  }
}

class _RecentTransactionsCard extends StatelessWidget {
  const _RecentTransactionsCard({required this.transactionsAsync});

  final AsyncValue<List<FinanceTransaction>> transactionsAsync;

  @override
  Widget build(BuildContext context) {
    return transactionsAsync.when(
      loading: () => const FinanceCard(
        title: 'Recent transactions',
        icon: Icons.receipt_long,
        child: Text('Loading transactions...'),
      ),
      error: (error, stack) => const FinanceCard(
        title: 'Recent transactions',
        icon: Icons.receipt_long,
        child: Text('Unable to load transactions right now.'),
      ),
      data: (transactions) {
        if (transactions.isEmpty) {
          return const FinanceCard(
            title: 'Recent transactions',
            icon: Icons.receipt_long,
            child: Text('No transactions yet. Add one to start tracking.'),
          );
        }

        final recent = transactions.take(4).toList();
        return FinanceCard(
          title: 'Recent transactions',
          icon: Icons.receipt_long,
          child: Column(
            children: [
              for (final tx in recent)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tx.merchant ?? tx.note ?? 'Transaction'),
                  subtitle: Text(tx.date.toString().substring(0, 10)),
                  trailing: Text(_signedAmount(tx)),
                ),
            ],
          ),
        );
      },
    );
  }

  String _signedAmount(FinanceTransaction transaction) {
    final sign = transaction.type == TransactionType.income ? '+' : '-';
    return '$sign${transaction.amount.format()}';
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
