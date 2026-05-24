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
    title: 'Daily Money',
    items: [
      AikoNavigationItem(
        label: 'Accounts',
        path: '/accounts',
        icon: Icons.account_balance_wallet_outlined,
        description:
            'Manage bank, cash, wallet, credit, loan, and asset accounts.',
      ),
    ],
  ),
  AikoNavigationGroup(
    title: 'Planning',
    items: [
      AikoNavigationItem(
        label: 'Debt and Loans',
        path: '/debt-loans',
        icon: Icons.payments_outlined,
        description: 'Compare snowball and avalanche payoff plans.',
      ),
      AikoNavigationItem(
        label: 'Credit Cards',
        path: '/credit-cards',
        icon: Icons.credit_card_outlined,
        description: 'Review limits, APR, rewards, and utilization.',
      ),
    ],
  ),
  AikoNavigationGroup(
    title: 'Wealth and Tax',
    items: [
      AikoNavigationItem(
        label: 'Portfolio',
        path: '/portfolio',
        icon: Icons.show_chart_outlined,
        description: 'Track holdings, gains, allocation, and rebalance alerts.',
        accentColor: AikoColors.analyticsTeal,
      ),
      AikoNavigationItem(
        label: 'Assets',
        path: '/assets',
        icon: Icons.home_work_outlined,
        description: 'Log assets and net worth records.',
        accentColor: AikoColors.analyticsTeal,
      ),
      AikoNavigationItem(
        label: 'Tax Center',
        path: '/tax-center',
        icon: Icons.request_quote_outlined,
        description: 'Review tax summaries, deductions, and estimates.',
      ),
      AikoNavigationItem(
        label: 'Accounting',
        path: '/accounting',
        icon: Icons.fact_check_outlined,
        description: 'Review journals, reconciliation, and ledger balances.',
      ),
    ],
  ),
  AikoNavigationGroup(
    title: 'Insights and AI',
    items: [
      AikoNavigationItem(
        label: 'Aiko Optimize',
        path: '/aiko-optimize',
        icon: Icons.tune_outlined,
        description: 'See ranked recommendations and next actions.',
        accentColor: AikoColors.premiumPurple,
      ),
      AikoNavigationItem(
        label: 'Aiko Review',
        path: '/aiko-review',
        icon: Icons.rate_review_outlined,
        description: 'Read monthly narrative reviews.',
        accentColor: AikoColors.premiumPurple,
      ),
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
        label: 'Reports',
        path: '/reports',
        icon: Icons.assessment_outlined,
        description: 'Build reports and chart summaries.',
      ),
      AikoNavigationItem(
        label: 'Export',
        path: '/export',
        icon: Icons.file_download_outlined,
        description: 'Create CSV, Excel-compatible, and PDF-ready outputs.',
      ),
      AikoNavigationItem(
        label: 'Import, Export, Backup',
        path: '/import-export-backup',
        icon: Icons.import_export,
        description: 'Import files, preview changes, export, and back up data.',
      ),
      AikoNavigationItem(
        label: 'Travel Mode',
        path: '/travel-mode',
        icon: Icons.flight_takeoff_outlined,
        description: 'Plan trips, currencies, and travel budgets.',
      ),
    ],
  ),
  AikoNavigationGroup(
    title: 'Settings and Security',
    items: [
      AikoNavigationItem(
        label: 'Settings',
        path: '/settings',
        icon: Icons.settings_outlined,
        description: 'Profile, privacy, workspace, and plan settings.',
      ),
      AikoNavigationItem(
        label: 'Notifications',
        path: '/notification-settings',
        icon: Icons.notifications_outlined,
        description: 'Configure bill, budget, goal, and insight alerts.',
      ),
      AikoNavigationItem(
        label: 'Devices',
        path: '/devices',
        icon: Icons.devices_outlined,
        description: 'Review trusted devices and active sessions.',
      ),
      AikoNavigationItem(
        label: 'Aiko Character',
        path: '/aiko-character',
        icon: Icons.face_retouching_natural_outlined,
        description: 'Adjust Aiko visibility and character preferences.',
        accentColor: AikoColors.premiumPurple,
      ),
      AikoNavigationItem(
        label: 'Subscription Plan',
        path: '/subscription-plan',
        icon: Icons.workspace_premium_outlined,
        description: 'Compare Free, Premium, and Pro access.',
        accentColor: AikoColors.premiumPurple,
      ),
    ],
  ),
];
