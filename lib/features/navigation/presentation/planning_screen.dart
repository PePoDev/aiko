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
      title: 'Investments',
      description: 'Track holdings, gains, allocation, and rebalance alerts.',
      path: '/portfolio',
      icon: Icons.show_chart_outlined,
      color: AikoColors.analyticsTeal,
    ),
    _PlanningItem(
      title: 'Asset Allocation',
      description: 'Analyze allocation by class, currency, and risk.',
      path: '/portfolio/allocation',
      icon: Icons.donut_small_outlined,
      color: AikoColors.analyticsTeal,
    ),
    _PlanningItem(
      title: 'Holding Detail',
      description: 'Inspect a single holding performance and history.',
      path: '/portfolio/holding',
      icon: Icons.trending_up_outlined,
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
