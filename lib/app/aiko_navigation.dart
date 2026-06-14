import 'package:flutter/material.dart';

import '../theme/aiko_colors.dart';

class AikoNavigationGroup {
  const AikoNavigationGroup({required this.title, required this.items});

  final String title;
  final List<AikoNavigationItem> items;
}

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

const aikoNavigationGroups = [
  AikoNavigationGroup(
    title: 'Planning',
    items: [
      AikoNavigationItem(
        label: 'Budget',
        path: '/budget',
        icon: Icons.pie_chart_outline,
        description: 'Plan category limits, alerts, and monthly spending pace.',
        accentColor: AikoColors.warningOrange,
      ),
      AikoNavigationItem(
        label: 'Goals',
        path: '/goals',
        icon: Icons.flag_outlined,
        description: 'Plan SMART goals and saving milestones.',
        accentColor: AikoColors.successGreen,
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
      AikoNavigationItem(
        label: 'Assets and Net Worth',
        path: '/assets-net-worth',
        icon: Icons.account_balance_wallet_outlined,
        description: 'View total assets, liabilities, and net worth over time.',
        accentColor: AikoColors.analyticsTeal,
      ),
      AikoNavigationItem(
        label: 'Travel Mode',
        path: '/travel-mode',
        icon: Icons.flight_takeoff_outlined,
        description: 'Plan trips, currencies, and travel budgets.',
        accentColor: AikoColors.primaryBlue,
      ),
    ],
  ),
  AikoNavigationGroup(
    title: 'Insights and AI',
    items: [
      AikoNavigationItem(
        label: 'Learning Hub',
        path: '/learning-hub',
        icon: Icons.school_outlined,
        description: 'Take lessons, quizzes, and glossary refreshers.',
      ),
    ],
  ),
  AikoNavigationGroup(
    title: 'Tools and Data',
    items: [
      AikoNavigationItem(
        label: 'Calculators',
        path: '/calculators',
        icon: Icons.calculate_outlined,
        description:
            'Run finance, loan, retirement, stock, and everyday calculators.',
      ),
      AikoNavigationItem(
        label: 'Monthly Report',
        path: '/reports/monthly',
        icon: Icons.summarize_outlined,
        description: 'Open the current monthly finance review.',
      ),
      AikoNavigationItem(
        label: 'Export',
        path: '/export',
        icon: Icons.file_download_outlined,
        description: 'Create CSV, Excel-compatible, and PDF-ready outputs.',
      ),
    ],
  ),
  AikoNavigationGroup(
    title: 'Settings and Security',
    items: [
      AikoNavigationItem(
        label: 'Notifications',
        path: '/notification-settings',
        icon: Icons.notifications_outlined,
        description: 'Configure recurring, budget, goal, and insight alerts.',
      ),
      AikoNavigationItem(
        label: 'Notifications Center',
        path: '/notifications',
        icon: Icons.notifications_active_outlined,
        description: 'Review recent alerts, updates, and financial reminders.',
      ),
      AikoNavigationItem(
        label: 'Profile & Security',
        path: '/profile-security',
        icon: Icons.admin_panel_settings_outlined,
        description: 'Manage account security, biometrics, and login alerts.',
      ),
    ],
  ),
];
