import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/aiko_colors.dart';

class PlanningScreen extends StatelessWidget {
  const PlanningScreen({super.key});

  static const _items = [
    _PlanningItem(
      title: 'Budget',
      description: 'Plan category limits, alerts, and monthly spending pace.',
      path: '/budget',
      icon: Icons.pie_chart_outline,
      color: AikoColors.warningOrange,
    ),
    _PlanningItem(
      title: 'Goals',
      description: 'Plan SMART goals and saving milestones.',
      path: '/goals',
      icon: Icons.flag_outlined,
      color: AikoColors.successGreen,
    ),
    _PlanningItem(
      title: 'Recurring Transactions',
      description: 'Track bills, subscriptions, renewals, and recurring plans.',
      path: '/bills-subscriptions',
      icon: Icons.event_repeat_outlined,
      color: AikoColors.primaryBlue,
    ),
    _PlanningItem(
      title: 'Debt and Loans',
      description: 'Compare snowball and avalanche payoff plans.',
      path: '/debt-loans',
      icon: Icons.payments_outlined,
      color: AikoColors.warningOrange,
    ),
    _PlanningItem(
      title: 'Credit Cards',
      description: 'Review limits, APR, rewards, and utilization.',
      path: '/credit-cards',
      icon: Icons.credit_card_outlined,
      color: AikoColors.primaryBlue,
    ),
    _PlanningItem(
      title: 'Accounts',
      description:
          'Manage bank, cash, wallet, credit, loan, and asset accounts.',
      path: '/accounts',
      icon: Icons.account_balance_wallet_outlined,
      color: AikoColors.primaryBlue,
    ),
    _PlanningItem(
      title: 'Categories',
      description: 'Organize transaction and budget categories.',
      path: '/categories',
      icon: Icons.category_outlined,
      color: AikoColors.analyticsTeal,
    ),
    _PlanningItem(
      title: 'Assets',
      description: 'Log assets and net worth records.',
      path: '/assets',
      icon: Icons.home_work_outlined,
      color: AikoColors.analyticsTeal,
    ),
    _PlanningItem(
      title: 'Tax Center',
      description: 'Review tax summaries, deductions, and estimates.',
      path: '/tax-center',
      icon: Icons.request_quote_outlined,
      color: AikoColors.warningOrange,
    ),
    _PlanningItem(
      title: 'Accounting',
      description: 'Review journals, reconciliation, and ledger balances.',
      path: '/accounting',
      icon: Icons.fact_check_outlined,
      color: AikoColors.primaryBlue,
    ),
    _PlanningItem(
      title: 'Portfolio',
      description: 'Track holdings, gains, allocation, and rebalance alerts.',
      path: '/portfolio',
      icon: Icons.show_chart_outlined,
      color: AikoColors.analyticsTeal,
    ),
    _PlanningItem(
      title: 'Travel Mode',
      description: 'Plan trips, currencies, and travel budgets.',
      path: '/travel-mode',
      icon: Icons.flight_takeoff_outlined,
      color: AikoColors.primaryBlue,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Planning')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: [
          for (final item in _items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(item.icon, color: item.color),
                  ),
                  title: Text(item.title),
                  subtitle: Text(item.description),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(item.path),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlanningItem {
  const _PlanningItem({
    required this.title,
    required this.description,
    required this.path,
    required this.icon,
    required this.color,
  });

  final String title;
  final String description;
  final String path;
  final IconData icon;
  final Color color;
}
