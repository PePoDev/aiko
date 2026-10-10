import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/aiko_character/presentation/aiko_avatar.dart';
import '../features/transactions/presentation/transaction_form_screen.dart';
import '../l10n/l10n.dart';
import '../shared/layout/adaptive_presentation.dart';
import 'aiko_navigation.dart';

/// Navigation for the expanded (web/desktop) layout. It shows the same
/// destinations as the phone bottom bar ([aikoPrimaryDestinations]) plus the
/// Tools list that phones reach through Settings ([aikoNavigationItems]).
class AikoSidebar extends StatelessWidget {
  const AikoSidebar({required this.location, required this.labeled, super.key});

  final String location;

  /// Full-width sidebar with labels and sections; otherwise an icon rail.
  final bool labeled;

  static const double labeledWidth = 264;
  static const double railWidth = 80;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final footer = <({String path, IconData icon, String label})>[
      (
        path: '/settings',
        icon: Icons.settings_outlined,
        label: l10n.settingsTitle,
      ),
      // Local-only builds show Profile too (name, photo, base currency);
      // the screen hides the cloud-account sections there.
      (path: '/profile', icon: Icons.person_outline, label: l10n.profileTitle),
    ];
    final selected = aikoSelectedPath(location, [
      for (final destination in aikoPrimaryDestinations) destination.path,
      for (final tool in aikoNavigationItems) tool.path,
      for (final item in footer) item.path,
    ]);

    return Container(
      width: labeled ? labeledWidth : railWidth,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Brand(labeled: labeled),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: labeled ? 16 : 12),
            child: _NewTransactionButton(labeled: labeled),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: labeled ? 12 : 8),
              children: [
                for (final destination in aikoPrimaryDestinations)
                  _SidebarItem(
                    path: destination.path,
                    label: destination.label(l10n),
                    icon: destination.icon,
                    selectedIcon: destination.selectedIcon,
                    accent: destination.accentColor,
                    selected: selected == destination.path,
                    labeled: labeled,
                  ),
                _SectionLabel(label: l10n.sidebarTools, labeled: labeled),
                for (final tool in aikoNavigationItems)
                  _SidebarItem(
                    path: tool.path,
                    label: tool.label(l10n),
                    icon: tool.icon,
                    accent: tool.accentColor,
                    selected: selected == tool.path,
                    labeled: labeled,
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          Padding(
            padding: EdgeInsets.fromLTRB(
              labeled ? 12 : 8,
              8,
              labeled ? 12 : 8,
              12,
            ),
            child: Column(
              children: [
                for (final item in footer)
                  _SidebarItem(
                    path: item.path,
                    label: item.label,
                    icon: item.icon,
                    selected: selected == item.path,
                    labeled: labeled,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.labeled});

  final bool labeled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mark = AikoAvatar(
      size: labeled ? 32 : 36,
      semanticLabel: 'Aiko', // l10n-ignore
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(labeled ? 20 : 0, 20, 16, 20),
      child: labeled
          ? Row(
              children: [
                mark,
                const SizedBox(width: 10),
                Text(
                  'Aiko', // l10n-ignore
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            )
          : Center(child: mark),
    );
  }
}

class _NewTransactionButton extends StatelessWidget {
  const _NewTransactionButton({required this.labeled});

  final bool labeled;

  void _open(BuildContext context) =>
      openAikoPage<void>(context, const TransactionFormScreen());

  @override
  Widget build(BuildContext context) {
    if (!labeled) {
      return Center(
        child: IconButton.filled(
          tooltip: context.l10n.newTransaction,
          onPressed: () => _open(context),
          icon: const Icon(Icons.add),
        ),
      );
    }
    return FilledButton.icon(
      key: const ValueKey('sidebar-new-transaction'),
      onPressed: () => _open(context),
      icon: const Icon(Icons.add),
      label: Text(context.l10n.newTransaction),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.labeled});

  final String label;
  final bool labeled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!labeled) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Divider(height: 1, color: theme.colorScheme.outlineVariant),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 6),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.path,
    required this.label,
    required this.icon,
    required this.selected,
    required this.labeled,
    this.selectedIcon,
    this.accent,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final Color? accent;
  final bool selected;
  final bool labeled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = accent ?? theme.colorScheme.primary;
    final foreground = selected ? active : theme.colorScheme.onSurfaceVariant;
    final item = Material(
      color: selected ? active.withValues(alpha: 0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () =>
            context.go(aikoNavigationTarget(path, reselected: selected)),
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: labeled
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              if (labeled)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 3,
                  height: selected ? 20 : 0,
                  margin: const EdgeInsets.only(right: 9),
                  decoration: BoxDecoration(
                    color: active,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              Icon(
                selected ? (selectedIcon ?? icon) : icon,
                size: 22,
                color: foreground,
              ),
              if (labeled) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: selected ? active : theme.colorScheme.onSurface,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: labeled ? item : Tooltip(message: label, child: item),
      ),
    );
  }
}
