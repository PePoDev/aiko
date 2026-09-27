import 'dart:async';
import '../core/offline/offline_store.dart';
import 'firebase_sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/transaction_capture/transaction_capture.dart';
import '../l10n/app_localizations.dart';
import '../theme/aiko_colors.dart';

class AuthenticatedShell extends ConsumerStatefulWidget {
  const AuthenticatedShell({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AuthenticatedShell> createState() => _AuthenticatedShellState();
}

class _AuthenticatedShellState extends ConsumerState<AuthenticatedShell> {
  late final AppLifecycleListener _lifecycle;
  StreamSubscription<Object>? _syncErrors;

  @override
  void initState() {
    super.initState();
    _syncErrors = OfflineStore.errors.stream.listen((error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A change could not sync. Check your connection and sign-in, then try again.',
          ),
        ),
      );
    });
    // Drain anything captured while we were away (and start listeners if the
    // user enabled capture). Fire-and-forget — failures are non-fatal.
    _lifecycle = AppLifecycleListener(onResume: _processCapture);
    _bootstrapCapture();
  }

  @override
  void dispose() {
    _syncErrors?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _bootstrapCapture() async {
    final settings = await TransactionCaptureSettings.load();
    if (settings.enabled) {
      await ref.read(transactionCaptureServiceProvider).start();
    }
    await _processCapture();
  }

  Future<void> _processCapture() async {
    try {
      await ref.read(transactionCaptureProcessorProvider).processInbox();
    } catch (_) {
      // Capture is best-effort; never block the app on it.
    }
  }

  List<_AikoNavItem> _getNavItems(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return [
      _AikoNavItem(
        label: l10n.accountsTab,
        path: '/accounts',
        icon: Icons.account_balance_wallet_outlined,
        selectedIcon: Icons.account_balance_wallet_rounded,
      ),
      _AikoNavItem(
        label: l10n.categoriesTab,
        path: '/categories',
        icon: Icons.category_outlined,
        selectedIcon: Icons.category_rounded,
      ),
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
    ];
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(firebaseSyncProvider);
    final location = GoRouterState.of(context).uri.path;
    final items = _getNavItems(context);
    final selectedIndex = _indexFor(location);

    void navigate(int index) {
      final item = items[index];
      if (index == selectedIndex && item.path == '/transactions') {
        context.go(
          '${item.path}?reset=${DateTime.now().microsecondsSinceEpoch}',
        );
      } else {
        context.go(item.path);
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 840;
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Row(
              children: [
                if (wide) ...[
                  NavigationRail(
                    extended: constraints.maxWidth >= 1200,
                    selectedIndex: selectedIndex,
                    onDestinationSelected: navigate,
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'Aiko',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    destinations: [
                      for (final item in items)
                        NavigationRailDestination(
                          icon: Icon(item.icon),
                          selectedIcon: Icon(item.selectedIcon),
                          label: Text(item.label),
                        ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                ],
                Expanded(child: widget.child),
              ],
            ),
          ),
          bottomNavigationBar: wide
              ? null
              : _AikoBottomNavigation(
                  selectedIndex: selectedIndex,
                  onSelected: navigate,
                  items: items,
                ),
        );
      },
    );
  }

  int _indexFor(String location) {
    if (location.startsWith('/accounts') ||
        location.startsWith('/credit-cards')) {
      return 0;
    }
    if (location.startsWith('/categories')) {
      return 1;
    }
    if (location.startsWith('/home') ||
        location.startsWith('/dashboard') ||
        location.startsWith('/settings') ||
        _isSecondaryRoute(location)) {
      return 2;
    }
    if (location.startsWith('/transactions')) {
      return 3;
    }
    if (location.startsWith('/aiko')) {
      return 4;
    }
    return 2;
  }

  bool _isSecondaryRoute(String location) {
    return location.startsWith('/transaction-rules') ||
        location.startsWith('/transaction-capture') ||
        location.startsWith('/reports/monthly') ||
        location.startsWith('/export') ||
        location.startsWith('/calculators') ||
        location.startsWith('/notifications') ||
        location.startsWith('/profile-security') ||
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

  static const double _barHeight = 60;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      elevation: 0,
      child: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: colorScheme.outlineVariant, width: 1),
            ),
          ),
          child: SizedBox(
            height: _barHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
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

  static const double _indicatorWidth = 32;
  static const double _indicatorHeight = 3;
  static const double _iconSize = 24;
  static const double _iconLabelGap = 2;
  static const double _indicatorIconGap = 4;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isAiko = item.path == '/aiko';

    final Color activeColor = isAiko
        ? AikoColors.premiumPurple
        : colorScheme.primary;

    final Color foreground;
    if (selected) {
      foreground = activeColor;
    } else if (isAiko) {
      foreground = AikoColors.premiumPurple.withValues(alpha: 0.6);
    } else {
      foreground = colorScheme.onSurfaceVariant;
    }

    final Color indicator = activeColor;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Tooltip(
        message: item.label,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: _indicatorHeight,
                  child: AnimatedContainer(
                    key: ValueKey('AikoNavIndicator_${item.path}'),
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    width: selected ? _indicatorWidth : 0,
                    decoration: BoxDecoration(
                      color: indicator,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ),
                const SizedBox(height: _indicatorIconGap),
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  color: foreground,
                  size: _iconSize,
                ),
                const SizedBox(height: _iconLabelGap),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: foreground,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
