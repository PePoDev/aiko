import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/aiko_colors.dart';

class AuthenticatedShell extends StatelessWidget {
  const AuthenticatedShell({required this.child, super.key});

  final Widget child;

  static const _items = [
    _AikoNavItem(
      label: 'Transactions',
      path: '/transactions',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
    ),
    _AikoNavItem(
      label: 'Budget',
      path: '/budget',
      icon: Icons.pie_chart_outline,
      selectedIcon: Icons.pie_chart,
    ),
    _AikoNavItem(
      label: 'Home',
      path: '/home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    _AikoNavItem(
      label: 'Insights',
      path: '/insights',
      icon: Icons.insights_outlined,
      selectedIcon: Icons.insights,
    ),
    _AikoNavItem(
      label: 'More',
      path: '/more',
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final selectedIndex = _indexFor(location);

    return Scaffold(
      body: SafeArea(bottom: false, child: child),
      bottomNavigationBar: _AikoBottomNavigation(
        selectedIndex: selectedIndex,
        onSelected: (index) => context.go(_items[index].path),
        items: _items,
      ),
    );
  }

  int _indexFor(String location) {
    if (location.startsWith('/transactions')) {
      return 0;
    }
    if (location.startsWith('/budget')) {
      return 1;
    }
    if (location.startsWith('/home')) {
      return 2;
    }
    if (location.startsWith('/insights')) {
      return 3;
    }
    if (location.startsWith('/more') || _isSecondaryRoute(location)) {
      return 4;
    }
    return 2;
  }

  bool _isSecondaryRoute(String location) {
    return location.startsWith('/accounts') ||
        location.startsWith('/transaction-rules') ||
        location.startsWith('/categories') ||
        location.startsWith('/goals') ||
        location.startsWith('/aiko-review') ||
        location.startsWith('/reports') ||
        location.startsWith('/export') ||
        location.startsWith('/aiko') ||
        location.startsWith('/calculators') ||
        location.startsWith('/settings') ||
        location.startsWith('/aiko-character') ||
        location.startsWith('/import-export-backup') ||
        location.startsWith('/bills') ||
        location.startsWith('/notification-settings') ||
        location.startsWith('/credit-cards') ||
        location.startsWith('/debt-loans') ||
        location.startsWith('/portfolio') ||
        location.startsWith('/assets') ||
        location.startsWith('/tax-center') ||
        location.startsWith('/accounting') ||
        location.startsWith('/learning-hub') ||
        location.startsWith('/travel-mode') ||
        location.startsWith('/devices') ||
        location.startsWith('/subscription-plan');
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
    final foreground = selected ? colorScheme.primary : colorScheme.onSurface;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Tooltip(
        message: item.label,
        child: InkWell(
          onTap: selected ? null : onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: selected ? colorScheme.primary : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    selected ? item.selectedIcon : item.icon,
                    color: selected ? colorScheme.onPrimary : foreground,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: foreground,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
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
