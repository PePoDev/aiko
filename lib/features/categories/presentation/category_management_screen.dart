import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/money/money.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../shared/widgets/screen_states.dart';
import '../../../theme/aiko_colors.dart';
import '../../transactions/domain/transaction.dart';
import '../domain/category.dart';
import '../domain/category_defaults.dart';
import 'category_editor_sheet.dart';
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
                  _showAddCategorySheet(context, initialType: CategoryType.expense);
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

          final totals = _CategoryTotals.compute(
            transactions: transactionsAsync.value ?? const <FinanceTransaction>[],
            baseCurrency: baseCurrency,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _CompactSection(
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
              ),
              const SizedBox(height: 16),
              _CompactSection(
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

class _CompactSection extends StatelessWidget {
  const _CompactSection({
    super.key,
    required this.title,
    required this.accent,
    required this.icon,
    required this.categories,
    required this.groups,
    required this.totals,
    required this.onCategoryTap,
    required this.onGroupEdit,
  });

  final String title;
  final Color accent;
  final IconData icon;
  final List<Category> categories;
  final List<CategoryGroup> groups;
  final _CategoryTotals totals;
  final ValueChanged<Category> onCategoryTap;
  final ValueChanged<CategoryGroup> onGroupEdit;

  String get _emptyTitle => title == 'Expense'
      ? 'No expense categories'
      : 'No income categories';
  String get _emptyMessage => title == 'Expense'
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

    final theme = Theme.of(context);
    final groupEntries = <_GroupEntry>[];
    for (final group in groups) {
      final groupCategories = categories
          .where((c) => _belongsToGroup(c, group))
          .toList(growable: false);
      if (groupCategories.isEmpty) continue;
      Money? groupTotal;
      int groupCount = 0;
      for (final category in groupCategories) {
        final amount = totals.amountForCategory(category.id);
        if (amount != null) {
          groupTotal = groupTotal == null ? amount : groupTotal + amount;
        }
        groupCount += totals.countForCategory(category.id);
      }
      groupEntries.add(_GroupEntry(
        group: group,
        categories: groupCategories,
        total: groupTotal,
        count: groupCount,
      ));
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
        sectionTotal =
            sectionTotal == null ? entry.total! : sectionTotal + entry.total!;
      }
      sectionCount += entry.count;
    }

    return Card(
      key: ValueKey('${title.toLowerCase()}-card'),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(
            title: title,
            accent: accent,
            icon: icon,
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
            _GroupBlock(
              entry: groupEntries[i],
              totals: totals,
              onCategoryTap: onCategoryTap,
              onGroupEdit: onGroupEdit,
            ),
          ],
        ],
      ),
    );
  }

  bool _belongsToGroup(Category category, CategoryGroup group) {
    if (group.id == CategoryGroupDefaults.unfiledGroupId) {
      return category.groupId == group.id ||
          category.groupId == null ||
          category.groupId!.isEmpty;
    }
    return category.groupId == group.id;
  }
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
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
            total == null ? '—' : AikoFormatters.money(total!),
            key: const ValueKey('section-total-amount'),
            style: theme.textTheme.titleSmall?.copyWith(
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

class _GroupBlock extends StatelessWidget {
  const _GroupBlock({
    required this.entry,
    required this.totals,
    required this.onCategoryTap,
    required this.onGroupEdit,
  });

  final _GroupEntry entry;
  final _CategoryTotals totals;
  final ValueChanged<Category> onCategoryTap;
  final ValueChanged<CategoryGroup> onGroupEdit;

  @override
  Widget build(BuildContext context) {
    final color = aikoHexColor(entry.group.color);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GroupHeader(
          title: entry.group.name,
          total: entry.total,
          count: entry.count,
          color: color,
          icon: aikoCategoryIcon(entry.group.icon),
          isSystem: entry.group.isSystem,
          onEdit: entry.group.isSystem
              ? null
              : () => onGroupEdit(entry.group),
        ),
        for (final category in entry.categories)
          _CategoryRow(
            category: category,
            amount: totals.amountForCategory(category.id),
            count: totals.countForCategory(category.id),
            onTap: category.isDefault ? null : () => onCategoryTap(category),
          ),
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.title,
    required this.total,
    required this.count,
    required this.color,
    required this.icon,
    required this.isSystem,
    this.onEdit,
  });

  final String title;
  final Money? total;
  final int count;
  final Color color;
  final IconData icon;
  final bool isSystem;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '$count',
              key: ValueKey('group-${title.toLowerCase()}-count'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              total == null ? '—' : AikoFormatters.money(total!),
              key: const ValueKey('group-total-amount'),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (onEdit != null) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.tune,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ],
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
  });

  final Category category;
  final Money? amount;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = aikoHexColor(category.color);
    final icon = aikoCategoryIcon(category.icon);

    return InkWell(
      key: ValueKey('category-row-${category.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 4, 12, 4),
        child: Row(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (category.isDefault)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.lock_outline,
                  size: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            SizedBox(
              width: 32,
              child: Text(
                '$count',
                textAlign: TextAlign.right,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 84,
              child: Text(
                amount == null ? '—' : AikoFormatters.money(amount!),
                textAlign: TextAlign.right,
                key: ValueKey('category-${category.id}-total'),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
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
