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
        label: 'Loan Calculator',
        path: '/loan-calculator',
        icon: Icons.payments_outlined,
        description: 'Estimate monthly payment, interest, and payoff impact.',
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
