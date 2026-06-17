import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/money/money.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../shared/widgets/screen_states.dart';
import '../../../theme/aiko_colors.dart';
import '../../transactions/domain/transaction.dart';
import '../domain/category.dart';
import '../domain/category_defaults.dart';
import 'category_budget_sheet.dart';
import 'category_editor_sheet.dart';
import 'category_group_budget_sheet.dart';
import 'category_group_editor_sheet.dart';
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
        title: const Text('Categories'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Add',
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
                onPressed: () => _showAddCategorySheet(context),
              ),
            );
          }

          // Use the provider's merged list directly: it already combines the
          // user's own groups with the 13 default groups, and — crucially —
          // folds any per-user budget overlay onto the (read-only) defaults.
          // Re-appending raw `CategoryGroupDefaults.all` here would discard
          // the saved group budget and the header would never show it.
          final groups = groupsAsync.value ?? CategoryGroupDefaults.all;

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
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _CategorySection(
                key: const ValueKey('section-expense'),
                title: 'Expense',
                accent: AikoColors.dangerRed,
                icon: Icons.arrow_upward_outlined,
                categories: expenseCategories,
                groups: groups,
                totals: totals,
                onCategoryTap: (category) =>
                    showCategoryEditorSheet(context, initialCategory: category),
                onGroupEdit: (group) =>
                    showCategoryGroupEditorSheet(context, initial: group),
                onGroupBudgetTap: (group) =>
                    showCategoryGroupBudgetSheet(context, group: group),
              ),
              const SizedBox(height: 16),
              _CategorySection(
                key: const ValueKey('section-income'),
                title: 'Income',
                accent: AikoColors.successGreen,
                icon: Icons.arrow_downward_outlined,
                categories: incomeCategories,
                groups: groups,
                totals: totals,
                onCategoryTap: (category) =>
                    showCategoryEditorSheet(context, initialCategory: category),
                onGroupEdit: (group) =>
                    showCategoryGroupEditorSheet(context, initial: group),
                onGroupBudgetTap: (group) =>
                    showCategoryGroupBudgetSheet(context, group: group),
              ),
            ],
          );
        },
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

  String get _emptyTitle => widget.title == 'Expense'
      ? 'No expense categories'
      : 'No income categories';
  String get _emptyMessage => widget.title == 'Expense'
      ? 'Add expense categories for bills, shopping, and daily spending.'
      : 'Add income categories for salary, side work, and other money coming in.';

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
  if (group.id == CategoryGroupDefaults.unfiledGroupId) {
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
              color: accent,
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
              color: accent,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GroupHeader(
          title: entry.group.name,
          total: entry.total,
          budget: entry.group.budgetLimit,
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
        ? '$count this month'
        : '$categoryCount ${categoryCount == 1 ? 'category' : 'categories'}';
    return InkWell(
      onTap: onToggle,
      child: ColoredBox(
        color: color.withValues(alpha: 0.08),
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
                      tooltip: 'Edit group',
                      visualDensity: VisualDensity.compact,
                      color: theme.colorScheme.onSurfaceVariant,
                      onPressed: onEdit,
                    )
                  else
                    const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      size: 22,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              if (budget != null) ...[
                const SizedBox(height: 8),
                _GroupBudgetProgress(
                  spent: total ?? Money.zero(budget!.currency),
                  limit: budget!,
                  color: color,
                ),
              ],
            ],
          ),
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
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              )
            : Container(
                key: const ValueKey('group-add-budget'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AikoColors.warningOrange.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  '+ Budget',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AikoColors.warningOrange,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
      ),
    );
  }
}

/// Animated progress bar of group spending against its group-level limit.
/// Fills from 0 on first paint and re-tweens when spent/limit changes; turns
/// danger-red once the limit is exceeded.
class _GroupBudgetProgress extends StatelessWidget {
  const _GroupBudgetProgress({
    required this.spent,
    required this.limit,
    required this.color,
  });

  final Money spent;
  final Money limit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = limit.amount <= Decimal.zero
        ? 0.0
        : (spent.amount / limit.amount).toDouble();
    final barColor = ratio > 1.0 ? AikoColors.dangerRed : color;
    return TweenAnimationBuilder<double>(
      key: const ValueKey('group-budget-progress'),
      tween: Tween(begin: 0, end: ratio.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      builder: (context, value, _) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          value: value,
          minHeight: 6,
          color: barColor,
          backgroundColor: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.amount,
    required this.count,
    required this.onTap,
    required this.onBudgetTap,
  });

  final Category category;
  final Money? amount;
  final int count;
  final VoidCallback? onTap;
  final VoidCallback onBudgetTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = aikoHexColor(category.color);
    final icon = aikoCategoryIcon(category.icon);
    final hasActivity = count > 0;

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
                            category.name,
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
                    if (hasActivity)
                      Text(
                        count == 1 ? '1 this month' : '$count this month',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _BudgetTrailing(
                amount: amount,
                limit: category.hasBudget ? category.monthlyLimit : null,
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

/// Tappable trailing slot on a category row. With a budget it shows
/// `spent/limit` and edits it; without one it shows the spent amount plus a
/// quiet `+ Budget` chip so adding a limit is always one tap away.
class _BudgetTrailing extends StatelessWidget {
  const _BudgetTrailing({
    required this.amount,
    required this.limit,
    required this.categoryId,
    required this.onTap,
  });

  final Money? amount;
  final Money? limit;
  final String categoryId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
        child: limit != null
            ? amountText
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (amount != null) ...[amountText, const SizedBox(width: 8)],
                  Container(
                    key: ValueKey('category-$categoryId-add-budget'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AikoColors.warningOrange.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      '+ Budget',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AikoColors.warningOrange,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _CategoryTotals {
  const _CategoryTotals(this._amounts, this._counts);

  static const _CategoryTotals empty = _CategoryTotals(
    <String, Money>{},
    <String, int>{},
  );

  factory _CategoryTotals.compute({
    required List<FinanceTransaction> transactions,
    required String baseCurrency,
  }) {
    if (transactions.isEmpty) return empty;
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
    return _CategoryTotals(amounts, counts);
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

  Money? amountForCategory(String? categoryId) {
    if (categoryId == null) return null;
    return _amounts[categoryId];
  }

  int countForCategory(String? categoryId) {
    if (categoryId == null) return 0;
    return _counts[categoryId] ?? 0;
  }
}
