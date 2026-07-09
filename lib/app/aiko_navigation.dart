import 'package:flutter/material.dart';

import '../theme/aiko_colors.dart';

class AikoNavigationItem {
  const AikoNavigationItem({
    required this.label,
    required this.path,
    required this.icon,
    this.description = '',
    this.accentColor = AikoColors.primaryBlue,
  });

  final String label;
  final String path;
  final IconData icon;
  final String description;
  final Color accentColor;
}

/// Settings entries are presented as a single ordered list. Order here is the
/// order the user sees in Settings.
const aikoNavigationItems = <AikoNavigationItem>[
  // Planning
  AikoNavigationItem(
    label: 'Budget: Pace',
    path: '/settings/pace',
    icon: Icons.speed_outlined,
    description: 'See whether this month is on track, per category.',
    accentColor: AikoColors.warningOrange,
  ),
  AikoNavigationItem(
    label: 'Budget: Safe to Spend',
    path: '/settings/safe-to-spend',
    icon: Icons.savings_outlined,
    description: 'Leftover after fixed bills, debt, goals, and current spend.',
    accentColor: AikoColors.primaryBlue,
  ),
  AikoNavigationItem(
    label: 'Budget: Cash Flow',
    path: '/settings/cash-flow',
    icon: Icons.waterfall_chart,
    description: 'Income vs expenses vs savings — month over month.',
    accentColor: AikoColors.analyticsTeal,
  ),
  AikoNavigationItem(
    label: 'Budget: Cash Flow (Sankey)',
    path: '/settings/cash-flow-sankey',
    icon: Icons.account_tree_outlined,
    description: 'Visual Sankey of where your income flows.',
    accentColor: AikoColors.analyticsTeal,
  ),

  AikoNavigationItem(
    label: 'Goals: Chance of Success',
    path: '/settings/chance-of-success',
    icon: Icons.auto_graph_outlined,
    description: 'Monte Carlo probability of hitting every goal on time.',
    accentColor: AikoColors.premiumPurple,
  ),
  AikoNavigationItem(
    label: 'Investments',
    path: '/portfolio',
    icon: Icons.show_chart_outlined,
    description: 'Track holdings, gains, allocation, and rebalance alerts.',
    accentColor: AikoColors.analyticsTeal,
  ),
  AikoNavigationItem(
    label: 'Asset Allocation',
    path: '/portfolio/allocation',
    icon: Icons.donut_small_outlined,
    description: 'Analyze allocation by class, currency, and risk.',
    accentColor: AikoColors.analyticsTeal,
  ),
  AikoNavigationItem(
    label: 'Holding Detail',
    path: '/portfolio/holding',
    icon: Icons.trending_up_outlined,
    description: 'Inspect a single holding performance and history.',
    accentColor: AikoColors.analyticsTeal,
  ),

  // Insights and AI
  AikoNavigationItem(
    label: 'Learning Hub',
    path: '/learning-hub',
    icon: Icons.school_outlined,
    description: 'Take lessons, quizzes, and glossary refreshers.',
  ),
  // Tools and Data
  AikoNavigationItem(
    label: 'Calculators',
    path: '/calculators',
    icon: Icons.calculate_outlined,
    description:
        'Run finance, loan, retirement, stock, and everyday calculators.',
  ),
  AikoNavigationItem(
    label: 'Export',
    path: '/export',
    icon: Icons.file_download_outlined,
    description: 'Create CSV, Excel-compatible, and PDF-ready outputs.',
  ),
];
