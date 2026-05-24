import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/finance_card.dart';
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
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Planning')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: [
          const FinanceCard(
            title: 'Planning',
            icon: Icons.route_outlined,
            prominent: true,
            child: Text(
              'Keep budgets, goals, and recurring commitments in one place.',
            ),
          ),
          const SizedBox(height: 16),
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
