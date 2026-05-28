import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../theme/aiko_colors.dart';

class AuthenticatedShell extends StatelessWidget {
  const AuthenticatedShell({required this.child, super.key});

  final Widget child;

  List<_AikoNavItem> _getNavItems(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return [
      _AikoNavItem(
        label: l10n.homeTab,
        path: '/home',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
      ),
      _AikoNavItem(
        label: l10n.transactionsTab,
        path: '/transactions',
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long,
      ),
      _AikoNavItem(
        label: l10n.aikoTab,
        path: '/aiko',
        icon: Icons.face_retouching_natural_outlined,
        selectedIcon: Icons.face_retouching_natural,
      ),
      _AikoNavItem(
        label: 'Planning',
        path: '/planning',
        icon: Icons.route_outlined,
        selectedIcon: Icons.route,
      ),
      _AikoNavItem(
        label: l10n.settingsTitle,
        path: '/settings',
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final items = _getNavItems(context);
    final selectedIndex = _indexFor(location);

    return Scaffold(
      body: SafeArea(bottom: false, child: child),
      bottomNavigationBar: _AikoBottomNavigation(
        selectedIndex: selectedIndex,
        onSelected: (index) {
          final item = items[index];
          if (index == selectedIndex && item.path == '/transactions') {
            context.go(
              '${item.path}?reset=${DateTime.now().microsecondsSinceEpoch}',
            );
            return;
          }
          context.go(item.path);
        },
        items: items,
      ),
    );
  }

  int _indexFor(String location) {
    if (location.startsWith('/home')) {
      return 0;
    }
    if (location.startsWith('/transactions')) {
      return 1;
    }
    if (location.startsWith('/aiko')) {
      return 2;
    }
    if (location.startsWith('/planning') ||
        location.startsWith('/budget') ||
        location.startsWith('/goals') ||
        location.startsWith('/bills') ||
        location.startsWith('/accounts') ||
        location.startsWith('/categories') ||
        location.startsWith('/credit-cards') ||
        location.startsWith('/debt-loans') ||
        location.startsWith('/portfolio') ||
        location.startsWith('/assets') ||
        location.startsWith('/tax-center') ||
        location.startsWith('/accounting') ||
        location.startsWith('/travel-mode')) {
      return 3;
    }
    if (location.startsWith('/settings') || _isSecondaryRoute(location)) {
      return 4;
    }
    return 0;
  }

  bool _isSecondaryRoute(String location) {
    return location.startsWith('/transaction-rules') ||
        location.startsWith('/reports') ||
        location.startsWith('/export') ||
        location.startsWith('/calculators') ||
        location.startsWith('/import-export-backup') ||
        location.startsWith('/notification-settings') ||
        location.startsWith('/learning-hub');
  }
}

class _AikoNavItem {
  const _AikoNavItem({
    required this.label,
    required this.path,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final String path;
  final IconData icon;
  final IconData selectedIcon;
}

class _AikoBottomNavigation extends StatelessWidget {
  const _AikoBottomNavigation({
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<_AikoNavItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final background = theme.brightness == Brightness.dark
        ? AikoColors.surfacePanelDarkStrong
        : AikoColors.surfacePanel;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: colorScheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: AikoColors.darkNavy.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              for (var index = 0; index < items.length; index++)
                Expanded(
                  child: _AikoBottomNavigationItem(
                    item: items[index],
                    selected: index == selectedIndex,
                    onTap: () => onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AikoBottomNavigationItem extends StatelessWidget {
  const _AikoBottomNavigationItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _AikoNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isAiko = item.path == '/aiko';

    Color foreground;
    if (isAiko) {
      foreground = selected ? Colors.white : AikoColors.premiumPurple;
    } else {
      foreground = selected ? colorScheme.primary : colorScheme.onSurface;
    }

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Tooltip(
        message: item.label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  width: isAiko ? 50 : 44,
                  height: isAiko ? 50 : 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isAiko && selected
                        ? const LinearGradient(
                            colors: [
                              AikoColors.premiumPurple,
                              Color(0xFF9B67F2),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isAiko
                        ? (selected
                              ? null
                              : AikoColors.premiumPurple.withValues(
                                  alpha: 0.12,
                                ))
                        : (selected ? colorScheme.primary : Colors.transparent),
                    boxShadow: isAiko
                        ? [
                            BoxShadow(
                              color: AikoColors.premiumPurple.withValues(
                                alpha: selected ? 0.3 : 0.08,
                              ),
                              blurRadius: selected ? 12 : 6,
                              offset: Offset(0, selected ? 4 : 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    selected ? item.selectedIcon : item.icon,
                    color: selected
                        ? (isAiko ? Colors.white : colorScheme.onPrimary)
                        : foreground,
                    size: isAiko ? 26 : 24,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isAiko ? AikoColors.premiumPurple : foreground,
                    fontWeight: selected || isAiko
                        ? FontWeight.w700
                        : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
