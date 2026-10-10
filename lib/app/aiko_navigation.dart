import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/aiko_colors.dart';

/// A primary destination. The phone bottom bar and the web/desktop sidebar are
/// both built from [aikoPrimaryDestinations], so a destination added there
/// appears in both layouts.
class AikoDestination {
  const AikoDestination({
    required this.path,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.accentColor,
  });

  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String Function(AppLocalizations l10n) label;

  /// Selected color; null uses the theme's primary color.
  final Color? accentColor;
}

String _homeLabel(AppLocalizations l10n) => l10n.homeTab;
String _transactionsLabel(AppLocalizations l10n) => l10n.transactionsTab;
String _accountsLabel(AppLocalizations l10n) => l10n.accountsTab;
String _categoriesLabel(AppLocalizations l10n) => l10n.categoriesTab;
String _aikoLabel(AppLocalizations l10n) => l10n.aikoTab;

/// Sidebar order: Overview first, as in most desktop apps.
const aikoPrimaryDestinations = <AikoDestination>[
  AikoDestination(
    path: '/home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
    label: _homeLabel,
  ),
  AikoDestination(
    path: '/transactions',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long,
    label: _transactionsLabel,
  ),
  AikoDestination(
    path: '/accounts',
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet_rounded,
    label: _accountsLabel,
  ),
  AikoDestination(
    path: '/categories',
    icon: Icons.category_outlined,
    selectedIcon: Icons.category_rounded,
    label: _categoriesLabel,
  ),
  AikoDestination(
    path: '/aiko',
    icon: Icons.face_retouching_natural_outlined,
    selectedIcon: Icons.face_retouching_natural,
    label: _aikoLabel,
    accentColor: AikoColors.premiumPurple,
  ),
];

/// Phone bottom-bar order keeps Overview in the thumb-friendly center.
const aikoBottomBarPaths = [
  '/accounts',
  '/categories',
  '/home',
  '/transactions',
  '/aiko',
];

/// Destinations that own secondary routes, so the right tab or sidebar entry
/// stays highlighted on pages without an entry of their own.
const _routeOwners = <String, String>{
  '/transaction-rules': '/transactions',
  '/transaction-capture': '/transactions',
  '/travel-mode': '/transactions',
  '/reports/monthly': '/transactions',
  '/account-form': '/accounts',
  '/profile': '/aiko',
  '/connect-line': '/profile',
};

/// Which of [entryPaths] to highlight for [location]: the longest entry that is
/// the location or a parent of it, else the route's owner, else Overview.
String aikoSelectedPath(String location, Iterable<String> entryPaths) {
  String? best;
  for (final path in entryPaths) {
    final matches = location == path || location.startsWith('$path/');
    if (matches && (best == null || path.length > best.length)) best = path;
  }
  if (best != null) return best;
  for (final MapEntry(key: route, value: owner) in _routeOwners.entries) {
    if (location == route || location.startsWith('$route/')) {
      return entryPaths.contains(owner)
          ? owner
          : aikoSelectedPath(owner, entryPaths);
    }
  }
  return '/home';
}

/// Where tapping a navigation entry goes. Re-tapping the selected Transactions
/// entry adds a fresh `reset` query so the list rebuilds with default filters.
String aikoNavigationTarget(
  String path, {
  required bool reselected,
  DateTime? now,
}) {
  if (reselected && path == '/transactions') {
    final stamp = (now ?? DateTime.now()).microsecondsSinceEpoch;
    return '$path?reset=$stamp';
  }
  return path;
}

class AikoNavigationItem {
  const AikoNavigationItem({
    required this.label,
    required this.path,
    required this.icon,
    required this.description,
    this.accentColor = AikoColors.primaryBlue,
  });

  final String Function(AppLocalizations l10n) label;
  final String path;
  final IconData icon;
  final String Function(AppLocalizations l10n) description;
  final Color accentColor;
}

String _toolChanceOfSuccessLabel(AppLocalizations l10n) =>
    l10n.toolChanceOfSuccess;
String _toolChanceOfSuccessDescription(AppLocalizations l10n) =>
    l10n.toolChanceOfSuccessDescription;

String _toolInvestmentsLabel(AppLocalizations l10n) => l10n.toolInvestments;
String _toolInvestmentsDescription(AppLocalizations l10n) =>
    l10n.toolInvestmentsDescription;

String _toolAssetAllocationLabel(AppLocalizations l10n) =>
    l10n.toolAssetAllocation;
String _toolAssetAllocationDescription(AppLocalizations l10n) =>
    l10n.toolAssetAllocationDescription;

String _toolHoldingDetailLabel(AppLocalizations l10n) => l10n.toolHoldingDetail;
String _toolHoldingDetailDescription(AppLocalizations l10n) =>
    l10n.toolHoldingDetailDescription;

String _toolLearningHubLabel(AppLocalizations l10n) => l10n.toolLearningHub;
String _toolLearningHubDescription(AppLocalizations l10n) =>
    l10n.toolLearningHubDescription;

String _toolCalculatorsLabel(AppLocalizations l10n) => l10n.toolCalculators;
String _toolCalculatorsDescription(AppLocalizations l10n) =>
    l10n.toolCalculatorsDescription;

String _toolExportLabel(AppLocalizations l10n) => l10n.toolExport;
String _toolExportDescription(AppLocalizations l10n) =>
    l10n.toolExportDescription;

/// Tools: shown as one ordered list in Settings (phone) and in the sidebar's
/// Tools section (web/desktop). Order here is the order the user sees.
const aikoNavigationItems = <AikoNavigationItem>[
  // Planning
  AikoNavigationItem(
    label: _toolChanceOfSuccessLabel,
    path: '/settings/chance-of-success',
    icon: Icons.auto_graph_outlined,
    description: _toolChanceOfSuccessDescription,
    accentColor: AikoColors.premiumPurple,
  ),
  AikoNavigationItem(
    label: _toolInvestmentsLabel,
    path: '/portfolio',
    icon: Icons.show_chart_outlined,
    description: _toolInvestmentsDescription,
    accentColor: AikoColors.analyticsTeal,
  ),
  AikoNavigationItem(
    label: _toolAssetAllocationLabel,
    path: '/portfolio/allocation',
    icon: Icons.donut_small_outlined,
    description: _toolAssetAllocationDescription,
    accentColor: AikoColors.analyticsTeal,
  ),
  AikoNavigationItem(
    label: _toolHoldingDetailLabel,
    path: '/portfolio/holding',
    icon: Icons.trending_up_outlined,
    description: _toolHoldingDetailDescription,
    accentColor: AikoColors.analyticsTeal,
  ),

  // Insights and AI
  AikoNavigationItem(
    label: _toolLearningHubLabel,
    path: '/learning-hub',
    icon: Icons.school_outlined,
    description: _toolLearningHubDescription,
  ),
  // Tools and Data
  AikoNavigationItem(
    label: _toolCalculatorsLabel,
    path: '/calculators',
    icon: Icons.calculate_outlined,
    description: _toolCalculatorsDescription,
  ),
  AikoNavigationItem(
    label: _toolExportLabel,
    path: '/export',
    icon: Icons.file_download_outlined,
    description: _toolExportDescription,
  ),
];
