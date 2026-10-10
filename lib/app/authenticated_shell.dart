import '../shared/layout/aiko_breakpoints.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/offline/offline_store.dart';
import '../features/transaction_capture/transaction_capture.dart';
import '../l10n/app_localizations.dart';
import 'aiko_navigation.dart';
import 'aiko_sidebar.dart';
import 'firebase_sync.dart';

/// The signed-in frame shared by web, Android and iOS. The window width picks
/// the layout ([AikoBreakpoints]): a sidebar with a centered content column on
/// wide windows, a bottom tab bar on phones. Both are built from
/// [aikoPrimaryDestinations], so navigation changes land in both.
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

  @override
  Widget build(BuildContext context) {
    ref.watch(firebaseSyncProvider);
    final location = GoRouterState.of(context).uri.path;
    final width = MediaQuery.sizeOf(context).width;

    if (AikoBreakpoints.layoutFor(width) == AikoLayout.expanded) {
      return Scaffold(
        body: SafeArea(
          bottom: false,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AikoSidebar(
                location: location,
                labeled: width >= AikoBreakpoints.labeledSidebar,
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: AikoBreakpoints.contentWidthFor(location),
                    ),
                    child: widget.child,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final l10n = AppLocalizations.of(context);
    final destinations = [
      for (final path in aikoBottomBarPaths)
        aikoPrimaryDestinations.firstWhere((item) => item.path == path),
    ];
    final selectedPath = aikoSelectedPath(location, aikoBottomBarPaths);
    return Scaffold(
      body: SafeArea(bottom: false, child: widget.child),
      bottomNavigationBar: _AikoBottomNavigation(
        items: [
          for (final destination in destinations)
            _AikoNavItem(
              label: destination.label(l10n),
              path: destination.path,
              icon: destination.icon,
              selectedIcon: destination.selectedIcon,
              accentColor: destination.accentColor,
            ),
        ],
        selectedPath: selectedPath,
        onSelected: (path) => context.go(
          aikoNavigationTarget(path, reselected: path == selectedPath),
        ),
      ),
    );
  }
}

class _AikoNavItem {
  const _AikoNavItem({
    required this.label,
    required this.path,
    required this.icon,
    required this.selectedIcon,
    this.accentColor,
  });

  final String label;
  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final Color? accentColor;
}

class _AikoBottomNavigation extends StatelessWidget {
  const _AikoBottomNavigation({
    required this.selectedPath,
    required this.onSelected,
    required this.items,
  });

  final String selectedPath;
  final ValueChanged<String> onSelected;
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
                  for (final item in items)
                    Expanded(
                      child: _AikoBottomNavigationItem(
                        item: item,
                        selected: item.path == selectedPath,
                        onTap: () => onSelected(item.path),
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
    final accent = item.accentColor;
    final Color activeColor = accent ?? colorScheme.primary;

    final Color foreground;
    if (selected) {
      foreground = activeColor;
    } else if (accent != null) {
      foreground = accent.withValues(alpha: 0.6);
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
