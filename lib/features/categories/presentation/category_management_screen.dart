import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/money/money.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../shared/widgets/screen_states.dart';
import '../../../theme/aiko_colors.dart';
import '../../../theme/aiko_status_colors.dart';
import '../../transactions/domain/transaction.dart';
import '../application/category_budget_progress_service.dart';
import '../domain/category.dart';
import '../domain/category_defaults.dart';
import 'category_budget_sheet.dart';
import 'category_editor_sheet.dart';
import 'category_group_budget_sheet.dart';
import 'category_group_editor_sheet.dart';
import 'category_names.dart';
import 'category_visual.dart';

class CategoryManagementScreen extends ConsumerWidget {
  const CategoryManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final groupsAsync = ref.watch(categoryGroupsProvider);
    final transactionsAsync = ref.watch(transactionsProvider);
    final profileAsync = ref.watch(profileProvider);
    final baseCurrency = profileAsync.value?.baseCurrency ?? 'USD';

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.categoriesTab),
        actions: [
          PopupMenuButton<String>(
            tooltip: context.l10n.add,
            icon: const Icon(Icons.add),
            onSelected: (value) {
              switch (value) {
                case 'new_category':
                  _showAddCategorySheet(
                    context,
                    initialType: CategoryType.expense,
                  );
                case 'new_group':
                  showCategoryGroupEditorSheet(context);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'new_category',
                child: Row(
                  children: [
                    Icon(Icons.category_outlined, size: 18),
                    SizedBox(width: 8),
                    Text(context.l10n.categoriesNewCategory),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'new_group',
                child: Row(
                  children: [
                    Icon(Icons.folder_outlined, size: 18),
                    SizedBox(width: 8),
                    Text(context.l10n.categoriesNewGroup),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.refresh(categoriesProvider.future),
            ref.refresh(categoryGroupsProvider.future),
            ref.refresh(transactionsProvider.future),
          ]);
        },
        child: categoriesAsync.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [AikoScreenState.loading()],
          ),
          error: (error, stack) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              AikoScreenState.error(
                title: context.l10n.categoriesUnavailableTitle,
                message: context.l10n.categoriesUnavailableMessage,
              ),
            ],
          ),
          data: (categories) {
            if (categories.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  AikoScreenState.empty(
                    title: context.l10n.categoriesEmptyTitle,
                    message: context.l10n.categoriesEmptyMessage,
                    action: PrimaryActionButton(
                      label: context.l10n.categoriesAddCategory,
                      icon: Icons.add_circle_outline,
                      onPressed: () => _showAddCategorySheet(context),
                    ),
                  ),
                ],
              );
            }

            final groups =
                groupsAsync.value ??
                (categories.any((category) => category.templateId != null)
                    ? CategoryGroupDefaults.forUser(categories.first.userId)
                    : CategoryGroupDefaults.all);

            final incomeCategories = categories
                .where((category) => category.type == CategoryType.income)
                .toList(growable: false);
            final expenseCategories = categories
                .where((category) => category.type == CategoryType.expense)
                .toList(growable: false);

            final totals = _CategoryTotals.compute(
              transactions:
                  transactionsAsync.value ?? const <FinanceTransaction>[],
              baseCurrency: baseCurrency,
              categories: categories,
            );

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _CategorySection(
                  key: const ValueKey('section-expense'),
                  title: context.l10n.categoryTypeExpense,
                  isExpense: true,
                  accent: AikoColors.dangerRed,
                  icon: Icons.arrow_upward_outlined,
                  categories: expenseCategories,
                  groups: groups,
                  totals: totals,
                  onCategoryTap: (category) => showCategoryEditorSheet(
                    context,
                    initialCategory: category,
                  ),
                  onGroupEdit: (group) =>
                      showCategoryGroupEditorSheet(context, initial: group),
                  onGroupBudgetTap: (group) =>
                      showCategoryGroupBudgetSheet(context, group: group),
                ),
                const SizedBox(height: 16),
                _CategorySection(
                  key: const ValueKey('section-income'),
                  title: context.l10n.categoryTypeIncome,
                  isExpense: false,
                  accent: AikoColors.successGreen,
                  icon: Icons.arrow_downward_outlined,
                  categories: incomeCategories,
                  groups: groups,
                  totals: totals,
                  onCategoryTap: (category) => showCategoryEditorSheet(
                    context,
                    initialCategory: category,
                  ),
                  onGroupEdit: (group) =>
                      showCategoryGroupEditorSheet(context, initial: group),
                  onGroupBudgetTap: (group) =>
                      showCategoryGroupBudgetSheet(context, group: group),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static void _showAddCategorySheet(
    BuildContext context, {
    CategoryType initialType = CategoryType.expense,
  }) {
    showCategoryEditorSheet(context, initialType: initialType);
  }
}

/// A typed (Income / Expense) card whose groups expand and collapse. Groups
/// start collapsed so the screen loads as a compact overview of the 13
/// default groups; expanding is opt-in. Expansion state lives here (keyed by
/// group id) so it survives provider refreshes — the section keeps a stable
/// [ValueKey].
class _CategorySection extends StatefulWidget {
  const _CategorySection({
    super.key,
    required this.title,
    required this.isExpense,
    required this.accent,
    required this.icon,
    required this.categories,
    required this.groups,
    required this.totals,
    required this.onCategoryTap,
    required this.onGroupEdit,
    required this.onGroupBudgetTap,
  });

  final String title;
  final bool isExpense;
  final Color accent;
  final IconData icon;
  final List<Category> categories;
  final List<CategoryGroup> groups;
  final _CategoryTotals totals;
  final ValueChanged<Category> onCategoryTap;
  final ValueChanged<CategoryGroup> onGroupEdit;
  final ValueChanged<CategoryGroup> onGroupBudgetTap;

  @override
  State<_CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<_CategorySection> {
  /// Group ids the user has expanded. Absent == collapsed (the default).
  final Set<String> _expanded = <String>{};

  String get _emptyTitle => widget.isExpense
      ? context.l10n.categoriesNoExpense
      : context.l10n.categoriesNoIncome;
  String get _emptyMessage => widget.isExpense
      ? context.l10n.categoriesNoExpenseMessage
      : context.l10n.categoriesNoIncomeMessage;

  @override
  Widget build(BuildContext context) {
    if (widget.categories.isEmpty) {
      return AikoScreenState.empty(
        title: _emptyTitle,
        message: _emptyMessage,
        action: null,
      );
    }

    final theme = Theme.of(context);
    final groupEntries = <_GroupEntry>[];
    for (final group in widget.groups) {
      final groupCategories = widget.categories
          .where((c) => _belongsToGroup(c, group))
          .toList(growable: false);
      if (groupCategories.isEmpty) continue;
      Money? groupTotal;
      int groupCount = 0;
      for (final category in groupCategories) {
        final amount = widget.totals.amountForCategory(category.id);
        if (amount != null) {
          groupTotal = groupTotal == null ? amount : groupTotal + amount;
        }
        groupCount += widget.totals.countForCategory(category.id);
      }
      groupEntries.add(
        _GroupEntry(
          group: group,
          categories: groupCategories,
          total: groupTotal,
          count: groupCount,
        ),
      );
    }

    if (groupEntries.isEmpty) {
      return AikoScreenState.empty(
        title: _emptyTitle,
        message: _emptyMessage,
        action: null,
      );
    }

    Money? sectionTotal;
    int sectionCount = 0;
    for (final entry in groupEntries) {
      if (entry.total != null) {
        sectionTotal = sectionTotal == null
            ? entry.total!
            : sectionTotal + entry.total!;
      }
      sectionCount += entry.count;
    }

    return Card(
      key: ValueKey('${widget.title.toLowerCase()}-card'),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(
            title: widget.title,
            accent: widget.accent,
            icon: widget.icon,
            total: sectionTotal,
            count: sectionCount,
          ),
          for (var i = 0; i < groupEntries.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: 12,
                endIndent: 12,
                color: theme.colorScheme.outlineVariant,
              ),
            _GroupAccordion(
              entry: groupEntries[i],
              totals: widget.totals,
              expanded: _expanded.contains(groupEntries[i].group.id),
              onToggle: () => _toggle(groupEntries[i].group.id),
              onCategoryTap: widget.onCategoryTap,
              onGroupEdit: widget.onGroupEdit,
              onGroupBudgetTap: widget.onGroupBudgetTap,
            ),
          ],
        ],
      ),
    );
  }

  void _toggle(String groupId) {
    setState(() {
      if (!_expanded.add(groupId)) {
        _expanded.remove(groupId);
      }
    });
  }
}

/// Trailing money string for a row/header: `-฿240/฿1000` when a budget
/// [limit] is set, otherwise just the spent amount (or `—` when neither).
String _spentOverLimit(Money? spent, Money? limit) {
  if (limit == null) return spent == null ? '—' : spent.format();
  final spentMoney = spent ?? Money.zero(limit.currency);
  return '${spentMoney.format()}/${limit.format()}';
}

bool _belongsToGroup(Category category, CategoryGroup group) {
  if (group.effectiveTemplateId == CategoryGroupDefaults.unfiledGroupId) {
    return category.groupId == group.id ||
        category.groupId == null ||
        category.groupId!.isEmpty;
  }
  return category.groupId == group.id;
}

class _GroupEntry {
  const _GroupEntry({
    required this.group,
    required this.categories,
    required this.total,
    required this.count,
  });

  final CategoryGroup group;
  final List<Category> categories;
  final Money? total;
  final int count;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.accent,
    required this.icon,
    required this.total,
    required this.count,
  });

  final String title;
  final Color accent;
  final IconData icon;
  final Money? total;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: accent.withValues(alpha: 0.06),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AikoStatusColors.of(context).textFor(accent),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            key: ValueKey('$title-section-count'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            total == null ? '—' : total!.format(),
            key: const ValueKey('section-total-amount'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AikoStatusColors.of(context).textFor(accent),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// One collapsible group: a tappable header that folds its category rows.
/// Tapping the header toggles expansion; the `tune` action edits the group.
class _GroupAccordion extends StatelessWidget {
  const _GroupAccordion({
    required this.entry,
    required this.totals,
    required this.expanded,
    required this.onToggle,
    required this.onCategoryTap,
    required this.onGroupEdit,
    required this.onGroupBudgetTap,
  });

  final _GroupEntry entry;
  final _CategoryTotals totals;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<Category> onCategoryTap;
  final ValueChanged<CategoryGroup> onGroupEdit;
  final ValueChanged<CategoryGroup> onGroupBudgetTap;

  @override
  Widget build(BuildContext context) {
    final color = aikoHexColor(entry.group.color);
    // Per-category spend slices for the group's stacked budget bar.
    final segments = <_BudgetSegment>[
      for (final c in entry.categories)
        if ((totals.amountForCategory(c.id)?.amount ?? Decimal.zero) >
            Decimal.zero)
          _BudgetSegment(
            aikoHexColor(c.color),
            totals.amountForCategory(c.id)!.amount.toDouble(),
            c.displayName(context.l10n),
          ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GroupHeader(
          title: entry.group.displayName(context.l10n),
          total: entry.total,
          budget: entry.group.budgetLimit,
          segments: segments,
          count: entry.count,
          categoryCount: entry.categories.length,
          color: color,
          icon: aikoCategoryIcon(entry.group.icon),
          expanded: expanded,
          onToggle: onToggle,
          onEdit: entry.group.isSystem ? null : () => onGroupEdit(entry.group),
          onBudgetTap: () => onGroupBudgetTap(entry.group),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 4),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: color.withValues(alpha: 0.35),
                          width: 2,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final category in entry.categories)
                          _CategoryRow(
                            category: category,
                            amount: totals.amountForCategory(category.id),
                            budget: totals.budgetFor(category.id),
                            count: totals.countForCategory(category.id),
                            onTap: category.isDefault
                                ? null
                                : () => onCategoryTap(category),
                            onBudgetTap: () => showCategoryBudgetSheet(
                              context,
                              category: category,
                            ),
                          ),
                      ],
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.title,
    required this.total,
    required this.budget,
    required this.segments,
    required this.count,
    required this.categoryCount,
    required this.color,
    required this.icon,
    required this.expanded,
    required this.onToggle,
    required this.onBudgetTap,
    this.onEdit,
  });

  final String title;
  final Money? total;
  final Money? budget;
  final List<_BudgetSegment> segments;
  final int count;
  final int categoryCount;
  final Color color;
  final IconData icon;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onBudgetTap;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = count > 0
        ? context.l10n.categoriesThisMonthCount(count)
        : context.l10n.categoriesCategoryCount(categoryCount);
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subtitle,
                        key: ValueKey('group-${title.toLowerCase()}-count'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _GroupBudgetTrailing(
                  total: total,
                  budget: budget,
                  color: color,
                  onTap: onBudgetTap,
                ),
                if (onEdit != null)
                  IconButton(
                    icon: const Icon(Icons.tune, size: 18),
                    tooltip: context.l10n.categoriesEditGroup,
                    visualDensity: VisualDensity.compact,
                    color: theme.colorScheme.onSurfaceVariant,
                    onPressed: onEdit,
                  )
                else
                  const SizedBox(width: 8),
                IconButton(
                  key: ValueKey('group-${title.toLowerCase()}-toggle'),
                  tooltip: expanded
                      ? context.l10n.categoriesCollapseGroup
                      : context.l10n.categoriesExpandGroup,
                  visualDensity: VisualDensity.compact,
                  color: theme.colorScheme.onSurfaceVariant,
                  onPressed: onToggle,
                  icon: AnimatedRotation(
                    turns: expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more, size: 22),
                  ),
                ),
              ],
            ),
            if (budget != null) ...[
              const SizedBox(height: 8),
              _GroupBudgetProgress(
                key: const ValueKey('group-budget-progress'),
                spent: total ?? Money.zero(budget!.currency),
                limit: budget!,
                segments: segments,
                color: color,
              ),
              if (segments.isNotEmpty) ...[
                const SizedBox(height: 6),
                _GroupStackedLegend(
                  segments: segments,
                  currency: budget!.currency,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Trailing budget slot on a group header. With a group limit it shows
/// `spent/limit` and edits it; without one it shows a quiet `+ Budget` chip so
/// setting a group envelope is one tap away. Owns its tap so it doesn't toggle
/// the accordion.
class _GroupBudgetTrailing extends StatelessWidget {
  const _GroupBudgetTrailing({
    required this.total,
    required this.budget,
    required this.color,
    required this.onTap,
  });

  final Money? total;
  final Money? budget;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: budget != null
            ? Text(
                _spentOverLimit(total, budget),
                key: const ValueKey('group-total-amount'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AikoStatusColors.of(context).textFor(color),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              )
            : _AddBudgetChip(chipKey: const ValueKey('group-add-budget')),
      ),
    );
  }
}

/// One category's slice of a group's stacked budget bar.
class _BudgetSegment {
  const _BudgetSegment(this.color, this.amount, this.label);
  final Color color;
  final double amount;
  final String label;
}

/// Stacked budget bar for a group: each [segments] slice is a category's
/// spend, sized against the group [limit]; the grey tail is headroom left.
/// When spend exceeds the limit the slices fill the whole bar (no tail) and a
/// danger-red outline flags the overrun — the trailing total carries the exact
/// figures, so 101% vs 150% is read from the number, not the bar.
class _GroupBudgetProgress extends StatelessWidget {
  const _GroupBudgetProgress({
    required this.spent,
    required this.limit,
    required this.segments,
    required this.color,
    super.key,
  });

  final Money spent;
  final Money limit;
  final List<_BudgetSegment> segments;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final limitD = limit.amount.toDouble();
    final spentD = spent.amount.toDouble();
    final over = limitD > 0 && spentD > limitD;
    // Bar represents the limit; once over it represents spend so slices fill.
    final denom = over ? spentD : (limitD <= 0 ? 1.0 : limitD);
    final remaining = over
        ? 0.0
        : (limitD - spentD).clamp(0.0, double.infinity);
    // ponytail: flex needs ints — scale to per-mille and floor at 1 so a tiny
    // slice still shows. Sub-rounding drift is invisible at bar widths.
    int weight(double v) => (v / denom * 1000).round().clamp(1, 1000000);

    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 8,
        child: segments.isEmpty
            ? ColoredBox(color: Theme.of(context).colorScheme.outlineVariant)
            : Row(
                children: [
                  for (final s in segments)
                    Expanded(
                      flex: weight(s.amount),
                      child: ColoredBox(color: s.color),
                    ),
                  if (remaining > 0)
                    Expanded(
                      flex: weight(remaining),
                      child: ColoredBox(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                ],
              ),
      ),
    );

    if (!over) return bar;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AikoColors.dangerRed, width: 1.5),
      ),
      child: bar,
    );
  }
}

/// Legend row that sits below the group stacked bar: one swatch + name +
/// amount per non-zero segment, flowing horizontally. Reads as a quick
/// "who's in the bar" map so the user doesn't have to count pixels.
class _GroupStackedLegend extends StatelessWidget {
  const _GroupStackedLegend({required this.segments, required this.currency});

  final List<_BudgetSegment> segments;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      children: [
        for (final s in segments)
          _GroupStackedLegendItem(segment: s, currency: currency),
      ],
    );
  }
}

class _GroupStackedLegendItem extends StatelessWidget {
  const _GroupStackedLegendItem({
    required this.segment,
    required this.currency,
  });

  final _BudgetSegment segment;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amount = Money.parse(segment.amount.toString(), currency).format();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: segment.color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${segment.label} $amount',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.amount,
    required this.budget,
    required this.count,
    required this.onTap,
    required this.onBudgetTap,
  });

  final Category category;

  /// This month's total, for categories without a budget.
  final Money? amount;

  /// Spend against the budget in its own period, with any rollover.
  final CategoryBudgetProgress? budget;
  final int count;
  final VoidCallback? onTap;
  final VoidCallback onBudgetTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = aikoHexColor(category.color);
    final icon = aikoCategoryIcon(category.icon);
    final hasActivity = count > 0;
    final limit = budget?.limit;
    final leftSub = limit != null
        ? context.l10n.categoriesSpentOf(budget!.used.format(), limit.format())
        : (hasActivity ? context.l10n.categoriesThisMonthCount(count) : null);

    return InkWell(
      key: ValueKey('category-row-${category.id}'),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            category.displayName(context.l10n),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (category.isDefault) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.lock_outline,
                            size: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ],
                    ),
                    if (leftSub != null)
                      Text(
                        leftSub,
                        key: ValueKey('category-${category.id}-left-sub'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _BudgetTrailing(
                amount: budget?.used ?? amount,
                limit: limit,
                period: category.budgetPeriod,
                categoryId: category.id,
                onTap: onBudgetTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tappable trailing slot on a category row. With a budget it leads with the
/// amount still left to spend (remaining-first) plus a per-day allowance, and
/// colours by how much of the limit is used; without one it shows the spent
/// amount plus a quiet `+ Budget` chip so adding a limit is always one tap away.
class _BudgetTrailing extends StatelessWidget {
  const _BudgetTrailing({
    required this.amount,
    required this.limit,
    required this.period,
    required this.categoryId,
    required this.onTap,
  });

  final Money? amount;
  final Money? limit;
  final CategoryBudgetPeriod period;
  final String categoryId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (limit != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: _RemainingFirst(
            spent: amount ?? Money.zero(limit!.currency),
            limit: limit!,
            period: period,
            categoryId: categoryId,
          ),
        ),
      );
    }

    final amountText = Text(
      _spentOverLimit(amount, limit),
      textAlign: TextAlign.right,
      key: ValueKey('category-$categoryId-total'),
      style: theme.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.onSurface,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (amount != null) ...[amountText, const SizedBox(width: 8)],
            _AddBudgetChip(
              chipKey: ValueKey('category-$categoryId-add-budget'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quiet "+ Budget" affordance shown when no limit is set. Neutral outline so
/// it sits back until tapped, rather than competing with real budget figures.
class _AddBudgetChip extends StatelessWidget {
  const _AddBudgetChip({required this.chipKey});

  final Key chipKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Container(
      key: chipKey,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        context.l10n.categoriesAddBudget,
        style: theme.textTheme.labelSmall?.copyWith(
          color: muted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Remaining-first budget readout: the bold number is what's left to spend,
/// coloured green/amber/red by how much of the limit is used, with the limit
/// and a per-day allowance demoted underneath. Over budget flips to the
/// overspend amount.
class _RemainingFirst extends StatelessWidget {
  const _RemainingFirst({
    required this.spent,
    required this.limit,
    required this.period,
    required this.categoryId,
  });

  final Money spent;
  final Money limit;
  final CategoryBudgetPeriod period;
  final String categoryId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final over = spent.amount > limit.amount;
    final ratio = limit.amount <= Decimal.zero
        ? 0.0
        : (spent.amount / limit.amount).toDouble();
    final color = over
        ? AikoColors.dangerRed
        : ratio >= 0.75
        ? AikoColors.warningOrange
        : AikoColors.successGreen;

    // ponytail: limit and spent may carry different currencies (a budget set in
    // one currency while base changed). The rest of this widget already
    // compares them as raw amounts, so do the same here and wrap once — no-FX,
    // no Money operator that would throw on a currency mismatch.
    final remaining = Money(
      amount: limit.amount - spent.amount,
      currency: limit.currency,
    );
    final headline = over
        ? '-${Money(amount: spent.amount - limit.amount, currency: limit.currency).format()}'
        : remaining.format();

    final daysLeft = _periodDaysLeft(period);
    final String sub;
    if (over) {
      sub = context.l10n.categoriesOverBudget;
    } else {
      final daily = remaining.amount.toDouble() / daysLeft;
      sub = context.l10n.categoriesPerDayLeft(
        daily.toStringAsFixed(0),
        daysLeft,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          headline,
          key: ValueKey('category-$categoryId-total'),
          textAlign: TextAlign.right,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: AikoStatusColors.of(context).textFor(color),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          sub,
          textAlign: TextAlign.right,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Whole days left in the current budget [period], today inclusive (min 1).
int _periodDaysLeft(CategoryBudgetPeriod period) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final end = budgetPeriodWindow(period, now).end;
  // Hours, rounded, so a daylight-saving change doesn't drop a day.
  return (end.difference(today).inHours / 24).round().clamp(1, 366);
}

class _CategoryTotals {
  const _CategoryTotals(
    this._amounts,
    this._counts, [
    this._budgets = const {},
  ]);

  factory _CategoryTotals.compute({
    required List<FinanceTransaction> transactions,
    required String baseCurrency,
    required List<Category> categories,
  }) {
    const progressService = CategoryBudgetProgressService();
    final budgets = <String, CategoryBudgetProgress>{
      for (final category in categories)
        if (category.hasBudget)
          category.id: progressService.progressFor(category, transactions),
    };
    if (transactions.isEmpty) {
      return _CategoryTotals(const {}, const {}, budgets);
    }
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final monthEnd = DateTime(now.year, now.month + 1);
    final amounts = <String, Money>{};
    final counts = <String, int>{};
    for (final tx in transactions) {
      if (tx.date.isBefore(monthStart) || !tx.date.isBefore(monthEnd)) continue;
      if (tx.amount.currency.toUpperCase() != baseCurrency.toUpperCase()) {
        continue;
      }
      final categoryId = tx.categoryId;
      if (categoryId == null || categoryId.isEmpty) continue;
      if (!_isCategoryTotalable(tx.type)) continue;
      final existing = amounts[categoryId];
      amounts[categoryId] = existing == null ? tx.amount : existing + tx.amount;
      counts[categoryId] = (counts[categoryId] ?? 0) + 1;
    }
    return _CategoryTotals(amounts, counts, budgets);
  }

  static bool _isCategoryTotalable(TransactionType type) {
    switch (type) {
      case TransactionType.expense:
      case TransactionType.refund:
      case TransactionType.fee:
      case TransactionType.income:
      case TransactionType.dividend:
      case TransactionType.interest:
        return true;
      case TransactionType.transfer:
      case TransactionType.transferIn:
      case TransactionType.transferOut:
      case TransactionType.investmentBuy:
      case TransactionType.investmentSell:
      case TransactionType.loanPayment:
      case TransactionType.creditCardPayment:
      case TransactionType.taxPayment:
      case TransactionType.adjustment:
        return false;
    }
  }

  final Map<String, Money> _amounts;
  final Map<String, int> _counts;
  final Map<String, CategoryBudgetProgress> _budgets;

  CategoryBudgetProgress? budgetFor(String categoryId) => _budgets[categoryId];

  Money? amountForCategory(String? categoryId) {
    if (categoryId == null) return null;
    return _amounts[categoryId];
  }

  int countForCategory(String? categoryId) {
    if (categoryId == null) return 0;
    return _counts[categoryId] ?? 0;
  }
}
