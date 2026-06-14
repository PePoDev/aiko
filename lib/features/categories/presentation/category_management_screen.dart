import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../shared/widgets/screen_states.dart';
import '../../../theme/aiko_colors.dart';
import '../domain/category.dart';
import '../domain/category_defaults.dart';
import 'category_editor_sheet.dart';
import 'category_group_editor_sheet.dart';
import 'category_visual.dart';

class CategoryManagementScreen extends ConsumerStatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  ConsumerState<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState
    extends ConsumerState<CategoryManagementScreen> {
  /// Tracks the expansion state of each group section, keyed by group id
  /// (including the 13 global default groups). All start expanded so users
  /// see their categories by default.
  final Map<String, bool> _expanded = <String, bool>{};

  void _toggleSection(String key) {
    setState(() {
      _expanded[key] = !(_expanded[key] ?? true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final groupsAsync = ref.watch(categoryGroupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Add',
            icon: const Icon(Icons.add),
            onSelected: (value) {
              switch (value) {
                case 'new_category':
                  _showAddCategorySheet(initialType: CategoryType.expense);
                case 'new_group':
                  _showAddGroupSheet();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'new_category',
                child: Row(
                  children: [
                    Icon(Icons.category_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('New category'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'new_group',
                child: Row(
                  children: [
                    Icon(Icons.folder_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('New group'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: categoriesAsync.when(
        loading: () => const AikoScreenState.loading(),
        error: (error, stack) => AikoScreenState.error(
          title: 'Categories are unavailable',
          message: 'Aiko could not load your categories right now.\n$error',
        ),
        data: (categories) {
          if (categories.isEmpty) {
            return AikoScreenState.empty(
              title: 'No categories yet',
              message:
                  'Create categories to organize transactions and budgets.',
              action: PrimaryActionButton(
                label: 'Add Category',
                icon: Icons.add_circle_outline,
                onPressed: () => _showAddCategorySheet(),
              ),
            );
          }

          // Always section the system-managed (and unfiled) categories under
          // the read-only default groups, even if the user-group load failed —
          // the 13 defaults are canonical and always appended in their
          // declared display order (income → investments → expense groups →
          // Other last).
          final groups = <CategoryGroup>[
            ...(groupsAsync.value ?? const <CategoryGroup>[]).where(
              (group) => !group.isSystem,
            ),
            ...CategoryGroupDefaults.all,
          ];

          final incomeCategories = categories
              .where((category) => category.type == CategoryType.income)
              .toList(growable: false);
          final expenseCategories = categories
              .where((category) => category.type == CategoryType.expense)
              .toList(growable: false);

          return CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              _CategorySectionSliver(
                key: const ValueKey('section-income'),
                title: 'Income',
                accent: AikoColors.successGreen,
                icon: Icons.arrow_downward_outlined,
                type: CategoryType.income,
                categories: incomeCategories,
                groups: groups,
                expanded: _expanded,
                onToggle: _toggleSection,
              ),
              _CategorySectionSliver(
                key: const ValueKey('section-expense'),
                title: 'Expense',
                accent: AikoColors.dangerRed,
                icon: Icons.arrow_upward_outlined,
                type: CategoryType.expense,
                categories: expenseCategories,
                groups: groups,
                expanded: _expanded,
                onToggle: _toggleSection,
              ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 32),
                sliver: SliverToBoxAdapter(child: SizedBox.shrink()),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddCategorySheet({
    CategoryType initialType = CategoryType.expense,
    String? groupIdHint,
  }) {
    showCategoryEditorSheet(
      context,
      initialType: initialType,
      groupIdHint: groupIdHint,
    );
  }

  void _showAddGroupSheet() {
    showCategoryGroupEditorSheet(context);
  }
}

class _CategorySectionSliver extends StatelessWidget {
  const _CategorySectionSliver({
    super.key,
    required this.title,
    required this.accent,
    required this.icon,
    required this.type,
    required this.categories,
    required this.groups,
    required this.expanded,
    required this.onToggle,
  });

  final String title;
  final Color accent;
  final IconData icon;
  final CategoryType type;
  final List<Category> categories;
  final List<CategoryGroup> groups;
  final Map<String, bool> expanded;
  final ValueChanged<String> onToggle;

  String get _emptyTitle => type == CategoryType.expense
      ? 'No expense categories'
      : 'No income categories';
  String get _emptyMessage => type == CategoryType.expense
      ? 'Add expense categories for bills, shopping, and daily spending.'
      : 'Add income categories for salary, side work, and other money coming in.';

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        sliver: SliverToBoxAdapter(
          child: AikoScreenState.empty(
            title: _emptyTitle,
            message: _emptyMessage,
            action: null,
          ),
        ),
      );
    }

    final sections = _buildSections();
    if (sections.isEmpty) {
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        sliver: SliverToBoxAdapter(
          child: AikoScreenState.empty(
            title: _emptyTitle,
            message: _emptyMessage,
            action: null,
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: _SectionHeader(title: title, accent: accent, icon: icon),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(top: 8),
            sliver: SliverList.builder(
              itemCount: sections.length,
              itemBuilder: (context, index) => Padding(
                padding: EdgeInsets.only(
                  bottom: index == sections.length - 1 ? 0 : 12,
                ),
                child: sections[index],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSections() {
    final widgets = <Widget>[];

    // Group sections in repository order (sortOrder, then createdAt, then
    // name); the 13 default groups are injected last in their declared order.
    // Each group is read-only (can't be renamed/deleted) but accepts user-
    // added custom categories filed into it. The "Other" group additionally
    // absorbs any unfiled custom category — see [_belongsToGroup].
    for (final group in groups) {
      final groupCategories = categories
          .where((c) => _belongsToGroup(c, group))
          .toList(growable: false);
      if (groupCategories.isEmpty) continue;
      widgets.add(
        _CategoryGroupSection(
          key: ValueKey('${type.name}-group-${group.id}'),
          group: group,
          categories: groupCategories,
          isExpanded: expanded[group.id] ?? true,
          onToggle: () => onToggle(group.id),
        ),
      );
    }

    return widgets;
  }

  /// A category belongs to [group] when its `groupId` matches. The
  /// [CategoryGroupDefaults.unfiledGroupId] group (currently "Other")
  /// additionally claims every unfiled custom category (`groupId` null or
  /// empty), so it plays the role the old "Ungrouped" bucket used to.
  bool _belongsToGroup(Category category, CategoryGroup group) {
    if (group.id == CategoryGroupDefaults.unfiledGroupId) {
      return category.groupId == group.id ||
          category.groupId == null ||
          category.groupId!.isEmpty;
    }
    return category.groupId == group.id;
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.accent,
    required this.icon,
  });

  final String title;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryGroupSection extends StatelessWidget {
  const _CategoryGroupSection({
    super.key,
    required this.group,
    required this.categories,
    required this.isExpanded,
    required this.onToggle,
  });

  final CategoryGroup group;
  final List<Category> categories;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final color = aikoHexColor(group.color);

    return Card(
      key: Key(
        group.id == CategoryGroupDefaults.unfiledGroupId
            ? 'system-group-section'
            : 'category-group-section',
      ),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _GroupHeader(
            title: group.name,
            subtitle:
                '${categories.length} categor'
                '${categories.length == 1 ? "y" : "ies"}',
            color: color,
            icon: aikoCategoryIcon(group.icon),
            isExpanded: isExpanded,
            onToggle: onToggle,
            onEdit: group.isSystem
                ? null
                : () => showCategoryGroupEditorSheet(context, initial: group),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: _CategoryCardGrid(categories: categories),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.isExpanded,
    required this.onToggle,
    this.onEdit,
  });

  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (onEdit != null) ...[
              IconButton(
                tooltip: 'Edit group',
                icon: const Icon(Icons.tune, size: 20),
                onPressed: onEdit,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                visualDensity: VisualDensity.compact,
              ),
            ],
            AnimatedRotation(
              turns: isExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 180),
              child: Icon(
                Icons.expand_more,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _CategoryCardGrid extends StatelessWidget {
  const _CategoryCardGrid({required this.categories});

  final List<Category> categories;

  @override
  Widget build(BuildContext context) {
    const spacing = 8.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 520
            ? 3
            : constraints.maxWidth >= 340
            ? 2
            : 1;
        final cardWidth =
            (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
            crossAxisCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: categories
              .map(
                (category) => SizedBox(
                  width: cardWidth,
                  child: _CategoryListCard(category: category),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _CategoryListCard extends StatelessWidget {
  const _CategoryListCard({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = aikoHexColor(category.color);
    final icon = aikoCategoryIcon(category.icon);

    return Card(
      key: ValueKey('category-card-${category.id}'),
      color: theme.cardColor,
      child: InkWell(
        onTap: category.isDefault
            ? null
            : () => showCategoryEditorSheet(context, initialCategory: category),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                if (category.isDefault) ...[
                  Icon(
                    Icons.lock_outline,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
