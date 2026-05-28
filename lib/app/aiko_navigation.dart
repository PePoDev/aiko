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
    ],
  ),
  AikoNavigationGroup(
    title: 'Settings and Security',
    items: [
      AikoNavigationItem(
        label: 'Notifications',
        path: '/notification-settings',
        icon: Icons.notifications_outlined,
        description: 'Configure bill, budget, goal, and insight alerts.',
      ),
    ],
  ),
];
