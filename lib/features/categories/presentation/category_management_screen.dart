import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../shared/widgets/screen_states.dart';
import '../../../theme/aiko_colors.dart';
import '../domain/category.dart';
import 'category_editor_sheet.dart';
import 'category_group_editor_sheet.dart';
import 'category_visual.dart';

const _ungroupedKey = '__ungrouped__';

class CategoryManagementScreen extends ConsumerStatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  ConsumerState<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState
    extends ConsumerState<CategoryManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _selectedTabIndex = 0;

  /// Tracks the expansion state of each group section. Keyed by group id;
  /// the special [_ungroupedKey] sentinel holds the ungrouped bucket. All
  /// start expanded so users see their categories by default.
  final Map<String, bool> _expanded = <String, bool>{_ungroupedKey: true};

  Color get _selectedTabColor =>
      _selectedTabIndex == 0 ? AikoColors.dangerRed : AikoColors.successGreen;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChanged);
  }

  void _handleTabChanged() {
    if (_selectedTabIndex == _tabController.index) return;
    setState(() => _selectedTabIndex = _tabController.index);
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    super.dispose();
  }

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
          IconButton(
            tooltip: 'Add category',
            icon: const Icon(Icons.add),
            onPressed: () => _showAddCategorySheet(),
          ),
          PopupMenuButton<String>(
            tooltip: 'Category tools',
            onSelected: (value) {
              if (value == 'new_group') {
                _showAddGroupSheet();
              }
            },
            itemBuilder: (context) => const [
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
          message: 'Aiko could not load your categories right now.',
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

          final groups = groupsAsync.value ?? const <CategoryGroup>[];

          final incomeCategories = categories
              .where((category) => category.type == CategoryType.income)
              .toList(growable: false);
          final expenseCategories = categories
              .where((category) => category.type == CategoryType.expense)
              .toList(growable: false);

          return Column(
            children: [
              Material(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: _selectedTabColor,
                  labelColor: _selectedTabColor,
                  unselectedLabelColor: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant,
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.arrow_upward_outlined),
                      text: 'Expense',
                    ),
                    Tab(
                      icon: Icon(Icons.arrow_downward_outlined),
                      text: 'Income',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _CategoryTypeView(
                      type: CategoryType.expense,
                      categories: expenseCategories,
                      groups: groups,
                      expanded: _expanded,
                      onToggle: _toggleSection,
                      onAddCategory: _showAddCategorySheet,
                    ),
                    _CategoryTypeView(
                      type: CategoryType.income,
                      categories: incomeCategories,
                      groups: groups,
                      expanded: _expanded,
                      onToggle: _toggleSection,
                      onAddCategory: _showAddCategorySheet,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddCategorySheet({String? groupIdHint}) {
    showCategoryEditorSheet(
      context,
      initialType: _selectedTabIndex == 0
          ? CategoryType.expense
          : CategoryType.income,
      groupIdHint: groupIdHint,
    );
  }

  void _showAddGroupSheet() {
    showCategoryGroupEditorSheet(context);
  }
}

class _CategoryTypeView extends StatelessWidget {
  const _CategoryTypeView({
    required this.type,
    required this.categories,
    required this.groups,
    required this.expanded,
    required this.onToggle,
    required this.onAddCategory,
  });

  final CategoryType type;
  final List<Category> categories;
  final List<CategoryGroup> groups;
  final Map<String, bool> expanded;
  final ValueChanged<String> onToggle;
  final void Function({String? groupIdHint}) onAddCategory;

  String get _emptyTitle => type == CategoryType.expense
      ? 'No expense categories'
      : 'No income categories';
  String get _emptyMessage => type == CategoryType.expense
      ? 'Add expense categories for bills, shopping, and daily spending.'
      : 'Add income categories for salary, side work, and other money coming in.';

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return AikoScreenState.empty(
        title: _emptyTitle,
        message: _emptyMessage,
        action: null,
      );
    }

    final sections = _buildSections();
    if (sections.isEmpty) {
      return AikoScreenState.empty(
        title: _emptyTitle,
        message: _emptyMessage,
        action: null,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: sections.length + 1,
      itemBuilder: (context, index) {
        if (index == sections.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _NewGroupButton(
              onPressed: () => showCategoryGroupEditorSheet(context),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: sections[index],
        );
      },
    );
  }

  List<Widget> _buildSections() {
    final widgets = <Widget>[];

    // Group sections in repository order (sortOrder, then createdAt, then name).
    for (final group in groups) {
      final groupCategories = categories
          .where((c) => c.groupId == group.id)
          .toList(growable: false);
      if (groupCategories.isEmpty) continue;
      widgets.add(
        _CategoryGroupSection(
          key: ValueKey('group-${group.id}'),
          group: group,
          categories: groupCategories,
          isExpanded: expanded[group.id] ?? true,
          onToggle: () => onToggle(group.id),
          onAddCategory: () => onAddCategory(groupIdHint: group.id),
        ),
      );
    }

    // Ungrouped section — system defaults and any unassigned custom categories.
    final ungrouped = categories
        .where((c) => c.groupId == null || c.groupId!.isEmpty)
        .toList(growable: false);
    if (ungrouped.isNotEmpty) {
      widgets.add(
        _UngroupedSection(
          key: const ValueKey('section-ungrouped'),
          categories: ungrouped,
          isExpanded: expanded[_ungroupedKey] ?? true,
          onToggle: () => onToggle(_ungroupedKey),
          onAddCategory: () => onAddCategory(),
        ),
      );
    }

    return widgets;
  }
}

class _NewGroupButton extends StatelessWidget {
  const _NewGroupButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: const Key('new-group-button'),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: Theme.of(context).colorScheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        foregroundColor: AikoColors.primaryBlue,
      ),
      icon: const Icon(Icons.folder_outlined),
      label: const Text(
        'New group',
        style: TextStyle(fontWeight: FontWeight.w600),
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
    required this.onAddCategory,
  });

  final CategoryGroup group;
  final List<Category> categories;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onAddCategory;

  @override
  Widget build(BuildContext context) {
    final color = aikoHexColor(group.color);

    return Card(
      key: const Key('category-group-section'),
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
            onEdit: () => showCategoryGroupEditorSheet(context, initial: group),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _CategoryCardGrid(categories: categories),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            key: Key('add-category-in-group-${group.id}'),
                            onPressed: onAddCategory,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add category'),
                            style: TextButton.styleFrom(
                              foregroundColor: color,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _UngroupedSection extends StatelessWidget {
  const _UngroupedSection({
    super.key,
    required this.categories,
    required this.isExpanded,
    required this.onToggle,
    required this.onAddCategory,
  });

  final List<Category> categories;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onAddCategory;

  @override
  Widget build(BuildContext context) {
    final hasCustom = categories.any((c) => !c.isDefault);
    final scheme = Theme.of(context).colorScheme;

    return Card(
      key: const Key('ungrouped-section'),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _GroupHeader(
            title: 'Ungrouped',
            subtitle:
                '${categories.length} categor${categories.length == 1 ? "y" : "ies"}'
                '${hasCustom ? "" : " · built-in"}',
            color: scheme.onSurfaceVariant,
            icon: Icons.inbox_outlined,
            isExpanded: isExpanded,
            onToggle: onToggle,
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
