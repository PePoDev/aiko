import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/money/money.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../shared/widgets/screen_states.dart';
import '../../../theme/aiko_colors.dart';
import '../../budgets/domain/budget.dart';
import '../../budgets/presentation/budget_form_screen.dart';
import '../../categories/domain/category.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/transaction_form_screen.dart';
import '../domain/dashboard_summary.dart';
import 'widgets/dashboard_due_items_widget.dart';

class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final dueItemsAsync = ref.watch(dashboardDueItemsProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.overview),
        actions: [
          IconButton(
            tooltip: l10n.aikoHub,
            onPressed: () => context.push('/more'),
            icon: const Icon(Icons.grid_view_outlined),
          ),
          IconButton(
            tooltip: l10n.settingsTitle,
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: summaryAsync.when(
          loading: () => [const AikoScreenState.loading()],
          error: (error, stack) => [
            AikoScreenState.error(
              title: l10n.dashboardUnavailable,
              message: l10n.dashboardUnavailableMessage,
            ),
          ],
          data: (summary) => [
            FinanceCard(
              title: l10n.hiAiko,
              icon: Icons.auto_awesome,
              accentColor: AikoColors.premiumPurple,
              prominent: true,
              child: Text(
                l10n.safeToSpendDescription(summary.safeToSpend.format()),
              ),
            ),
            const SizedBox(height: 16),
            const _OverviewQuickStatsRow(),
            const SizedBox(height: 16),
            FinanceCard(
              title: l10n.safeToSpend,
              icon: Icons.savings_outlined,
              prominent: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AmountText(summary.safeToSpend.format()),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _safeToSpendProgress(summary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.safeToSpendWeekly,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FinanceCard(
              title: l10n.monthlyCashFlow,
              icon: Icons.trending_up,
              accentColor: AikoColors.analyticsTeal,
              child: Column(
                children: [
                  _MetricLine(
                    label: l10n.income,
                    value: summary.monthlyIncome.format(),
                    color: AikoColors.successGreen,
                  ),
                  const SizedBox(height: 8),
                  _MetricLine(
                    label: l10n.spending,
                    value: summary.monthlySpending.format(),
                    color: AikoColors.warningOrange,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FinanceCard(
              title: l10n.pace,
              icon: Icons.speed,
              accentColor: AikoColors.deepBlue,
              child: Text(
                summary.paceStatus.isFast ? l10n.paceAhead : l10n.paceOnTrack,
              ),
            ),
            const SizedBox(height: 16),
            const _OverviewAnalyticsWidgets(),
            const SizedBox(height: 16),
            dueItemsAsync.when(
              loading: () => FinanceCard(
                title: l10n.upcomingDueDates,
                icon: Icons.event_available_outlined,
                child: Text(l10n.loadingBills),
              ),
              error: (error, stack) => FinanceCard(
                title: l10n.upcomingDueDates,
                icon: Icons.event_available_outlined,
                child: Text(l10n.unableToLoadDueDates),
              ),
              data: (items) => DashboardDueItemsWidget(items: items),
            ),
          ],
        ),
      ),
      floatingActionButton: const _QuickAddMenu(),
    );
  }

  double _safeToSpendProgress(DashboardSummary summary) {
    if (summary.monthlyIncome.amount <=
        Money.zero(summary.monthlyIncome.currency).amount) {
      return 0;
    }
    final value =
        summary.safeToSpend.amount.toDouble() /
        summary.monthlyIncome.amount.toDouble();
    return value.clamp(0.0, 1.0);
  }
}

class _OverviewQuickStatsRow extends ConsumerWidget {
  const _OverviewQuickStatsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsProvider);
    final accountsAsync = ref.watch(accountsProvider);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: budgetsAsync.when(
              loading: () => const _OverviewMiniCard(
                title: 'Daily spending',
                value: 'Loading',
                caption: 'Daily limit',
                icon: Icons.today_outlined,
                accentColor: AikoColors.warningOrange,
              ),
              error: (_, _) => const _OverviewMiniCard(
                title: 'Daily spending',
                value: 'Unavailable',
                caption: 'Daily limit',
                icon: Icons.today_outlined,
                accentColor: AikoColors.warningOrange,
              ),
              data: (budgets) {
                Budget? dailyBudget;
                for (final budget in budgets) {
                  if (budget.isDailySpending) {
                    dailyBudget = budget;
                    break;
                  }
                }
                return _OverviewMiniCard(
                  title: 'Daily spending',
                  value: dailyBudget?.amount.format() ?? 'Not set',
                  caption: 'Daily limit',
                  icon: Icons.today_outlined,
                  accentColor: AikoColors.warningOrange,
                  onTap: dailyBudget == null
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                BudgetFormScreen(initialBudget: dailyBudget),
                          ),
                        ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: accountsAsync.when(
              loading: () => const _OverviewMiniCard(
                title: 'Accounts',
                value: 'Loading',
                caption: 'Connected accounts',
                icon: Icons.account_balance_wallet_outlined,
                accentColor: AikoColors.analyticsTeal,
              ),
              error: (_, _) => const _OverviewMiniCard(
                title: 'Accounts',
                value: 'Unavailable',
                caption: 'Connected accounts',
                icon: Icons.account_balance_wallet_outlined,
                accentColor: AikoColors.analyticsTeal,
              ),
              data: (accounts) {
                final activeCount = accounts
                    .where((account) => account.isActive)
                    .length;
                return _OverviewMiniCard(
                  title: 'Accounts',
                  value: '$activeCount',
                  caption: activeCount == 1
                      ? 'Active account'
                      : 'Active accounts',
                  icon: Icons.account_balance_wallet_outlined,
                  accentColor: AikoColors.analyticsTeal,
                  onTap: () => context.push('/accounts'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewMiniCard extends StatelessWidget {
  const _OverviewMiniCard({
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
    required this.accentColor,
    this.onTap,
  });

  final String title;
  final String value;
  final String caption;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AikoColors.mutedText,
            ),
          ),
        ],
      ),
    );

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: content,
      ),
    );
  }
}

class _QuickAddMenu extends StatelessWidget {
  const _QuickAddMenu();

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'quick-add-main',
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const TransactionFormScreen()),
      ),
      child: const Icon(Icons.add),
    );
  }
}

class _OverviewAnalyticsWidgets extends ConsumerWidget {
  const _OverviewAnalyticsWidgets();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final budgetsAsync = ref.watch(budgetsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return transactionsAsync.when(
      loading: () => const FinanceCard(
        title: 'Daily summary',
        icon: Icons.bar_chart_outlined,
        child: Text('Loading transaction analytics...'),
      ),
      error: (error, stack) => FinanceCard(
        title: 'Daily summary',
        icon: Icons.bar_chart_outlined,
        child: Text('Unable to load transaction analytics right now.'),
      ),
      data: (transactions) {
        final budgets =
            budgetsAsync.whenOrNull(data: (items) => items) ?? const <Budget>[];
        final categories =
            categoriesAsync.whenOrNull(data: (items) => items) ??
            const <Category>[];

        return Column(
          children: [
            _DailySummaryCard(
              transactions: transactions,
              onTap: () => _openAnalyticsDetail(
                context,
                kind: _AnalyticsWidgetKind.dailySummary,
                transactions: transactions,
                budgets: budgets,
                categories: categories,
              ),
            ),
            const SizedBox(height: 16),
            _MonthlyNetEarningsCard(
              transactions: transactions,
              onTap: () => _openAnalyticsDetail(
                context,
                kind: _AnalyticsWidgetKind.netEarnings,
                transactions: transactions,
                budgets: budgets,
                categories: categories,
              ),
            ),
            const SizedBox(height: 16),
            _CategoryBudgetCard(
              transactions: transactions,
              budgets: budgets,
              categories: categories,
              onTap: () => _openAnalyticsDetail(
                context,
                kind: _AnalyticsWidgetKind.categoryBudgets,
                transactions: transactions,
                budgets: budgets,
                categories: categories,
              ),
            ),
            const SizedBox(height: 16),
            _SpendingCalendarCard(
              transactions: transactions,
              onTap: () => _openAnalyticsDetail(
                context,
                kind: _AnalyticsWidgetKind.spendingCalendar,
                transactions: transactions,
                budgets: budgets,
                categories: categories,
              ),
            ),
          ],
        );
      },
    );
  }

  void _openAnalyticsDetail(
    BuildContext context, {
    required _AnalyticsWidgetKind kind,
    required List<FinanceTransaction> transactions,
    required List<Budget> budgets,
    required List<Category> categories,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _AnalyticsDetailScreen(
          kind: kind,
          transactions: transactions,
          budgets: budgets,
          categories: categories,
        ),
      ),
    );
  }
}

enum _AnalyticsWidgetKind {
  dailySummary,
  netEarnings,
  categoryBudgets,
  spendingCalendar,
}

class _DailySummaryCard extends StatelessWidget {
  const _DailySummaryCard({
    required this.transactions,
    this.daysToShow = 7,
    this.onTap,
  });

  final List<FinanceTransaction> transactions;
  final int daysToShow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(DateTime.now());
    final days = [
      for (var offset = daysToShow - 1; offset >= 0; offset--)
        today.subtract(Duration(days: offset)),
    ];
    final buckets = [
      for (final day in days)
        _DailyBucket(
          day: day,
          income: _sumTransactionsForDay(
            transactions,
            day,
            TransactionType.income,
          ),
          expense: _sumTransactionsForDay(
            transactions,
            day,
            TransactionType.expense,
          ),
        ),
    ];
    final maxValue = buckets.fold<double>(
      0,
      (max, bucket) =>
          [max, bucket.income, bucket.expense].reduce((a, b) => a > b ? a : b),
    );
    final sevenDayAverage = _averageDailyExpense(transactions, today, 7);
    final thirtyDayAverage = _averageDailyExpense(transactions, today, 30);

    return FinanceCard(
      title: 'Daily summary',
      icon: Icons.bar_chart_outlined,
      accentColor: AikoColors.analyticsTeal,
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: maxValue <= 0 ? 10 : maxValue * 1.2,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= buckets.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _weekdayLabel(buckets[index].day),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var index = 0; index < buckets.length; index++)
                    BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: buckets[index].income,
                          color: AikoColors.successGreen,
                          width: 8,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        BarChartRodData(
                          toY: buckets[index].expense,
                          color: AikoColors.dangerRed,
                          width: 8,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const _LegendDot(color: AikoColors.successGreen, label: 'Income'),
              const SizedBox(width: 16),
              const _LegendDot(color: AikoColors.dangerRed, label: 'Expense'),
              const Spacer(),
              Text(
                '7d avg \$${sevenDayAverage.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Average spending:',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 2),
              Text(
                '7 days: \$${sevenDayAverage.toStringAsFixed(0)} per day',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                '30 days: \$${thirtyDayAverage.toStringAsFixed(0)} per day',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthlyNetEarningsCard extends StatelessWidget {
  const _MonthlyNetEarningsCard({
    required this.transactions,
    this.monthsToShow = 4,
    this.onTap,
  });

  final List<FinanceTransaction> transactions;
  final int monthsToShow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = [
      for (var offset = monthsToShow - 1; offset >= 0; offset--)
        DateTime(now.year, now.month - offset, 1),
    ];
    final buckets = [
      for (final month in months)
        _MonthlyBucket(
          month: month,
          income: _sumTransactionsForMonth(
            transactions,
            month,
            TransactionType.income,
          ),
          expense: _sumTransactionsForMonth(
            transactions,
            month,
            TransactionType.expense,
          ),
        ),
    ];
    final maxValue = buckets.fold<double>(
      0,
      (max, bucket) =>
          [max, bucket.income, bucket.expense].reduce((a, b) => a > b ? a : b),
    );
    final latest = buckets.last;
    final net = latest.income - latest.expense;

    return FinanceCard(
      title: 'Net earnings',
      icon: Icons.stacked_bar_chart_outlined,
      accentColor: AikoColors.deepBlue,
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: maxValue <= 0 ? 10 : maxValue * 1.2,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= buckets.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _monthShortLabel(buckets[index].month),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var index = 0; index < buckets.length; index++)
                    BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: buckets[index].income,
                          color: AikoColors.successGreen,
                          width: 12,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        BarChartRodData(
                          toY: buckets[index].expense,
                          color: AikoColors.dangerRed,
                          width: 12,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const _LegendDot(color: AikoColors.successGreen, label: 'Income'),
              const SizedBox(width: 16),
              const _LegendDot(color: AikoColors.dangerRed, label: 'Expense'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'This month net: \$${net.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: net >= 0 ? AikoColors.successGreen : AikoColors.dangerRed,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBudgetCard extends StatelessWidget {
  const _CategoryBudgetCard({
    required this.transactions,
    required this.budgets,
    required this.categories,
    this.maxRows = 5,
    this.onTap,
  });

  final List<FinanceTransaction> transactions;
  final List<Budget> budgets;
  final List<Category> categories;
  final int maxRows;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthExpenses = transactions
        .where(
          (tx) =>
              tx.type == TransactionType.expense &&
              tx.date.year == now.year &&
              tx.date.month == now.month,
        )
        .toList(growable: false);
    final usageByCategory = <String, double>{};
    for (final transaction in monthExpenses) {
      final categoryId = transaction.categoryId ?? 'uncategorized';
      usageByCategory[categoryId] =
          (usageByCategory[categoryId] ?? 0) +
          transaction.amount.amount.toDouble();
    }
    final categoryById = {
      for (final category in categories) category.id: category,
    };
    final budgetByCategory = {
      for (final budget in budgets.where(
        (budget) =>
            budget.status == BudgetStatus.active &&
            !budget.periodEnd.isBefore(DateTime(now.year, now.month, 1)) &&
            budget.periodStart.isBefore(DateTime(now.year, now.month + 1, 1)),
      ))
        budget.categoryId: budget,
    };
    final rows =
        usageByCategory.entries
            .map(
              (entry) => _CategoryUsage(
                categoryId: entry.key,
                label: categoryById[entry.key]?.name ?? 'Uncategorized',
                used: entry.value,
                budget:
                    budgetByCategory[entry.key]?.amount.amount.toDouble() ?? 0,
                color: _categoryColor(categoryById[entry.key], entry.key),
              ),
            )
            .toList()
          ..sort((a, b) => b.used.compareTo(a.used));

    final chartRows = rows.isEmpty
        ? [
            const _CategoryUsage(
              categoryId: 'none',
              label: 'No spending',
              used: 1,
              budget: 0,
              color: AikoColors.borderSubtle,
            ),
          ]
        : rows;

    return FinanceCard(
      title: 'Category budgets',
      icon: Icons.pie_chart_outline,
      accentColor: AikoColors.premiumPurple,
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 190,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 42,
                sections: [
                  for (final row in chartRows.take(6))
                    PieChartSectionData(
                      value: row.used,
                      color: row.color,
                      title: row.label == 'No spending'
                          ? ''
                          : '\$${row.used.toStringAsFixed(0)}',
                      radius: 54,
                      titleStyle: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: Colors.white),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            Text(
              'No category spending recorded this month yet.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            for (final row in rows.take(maxRows)) ...[
              _CategoryBudgetRow(row: row),
              if (row != rows.take(maxRows).last) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _SpendingCalendarCard extends StatelessWidget {
  const _SpendingCalendarCard({
    required this.transactions,
    this.dotScale = 1,
    this.onTap,
  });

  final List<FinanceTransaction> transactions;
  final double dotScale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final leadingEmptyCells = firstDay.weekday % 7;
    final spendingByDay = <int, double>{};
    for (final transaction in transactions.where(
      (tx) =>
          tx.type == TransactionType.expense &&
          tx.date.year == now.year &&
          tx.date.month == now.month,
    )) {
      spendingByDay[transaction.date.day] =
          (spendingByDay[transaction.date.day] ?? 0) +
          transaction.amount.amount.toDouble();
    }
    final maxSpend = spendingByDay.values.fold<double>(
      0,
      (max, value) => value > max ? value : max,
    );

    return FinanceCard(
      title: 'Spending calendar',
      icon: Icons.calendar_month_outlined,
      accentColor: AikoColors.warningOrange,
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
      child: Column(
        children: [
          Row(
            children: [
              for (final label in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AikoColors.mutedText,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: leadingEmptyCells + daysInMonth,
            itemBuilder: (context, index) {
              if (index < leadingEmptyCells) {
                return const SizedBox.shrink();
              }
              final day = index - leadingEmptyCells + 1;
              final spend = spendingByDay[day] ?? 0;
              final dotSize = spend <= 0
                  ? 0.0
                  : (5 + ((spend / (maxSpend == 0 ? spend : maxSpend)) * 11)) *
                        dotScale;

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$day', style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 18,
                    child: Center(
                      child: Container(
                        width: dotSize,
                        height: dotSize,
                        decoration: BoxDecoration(
                          color: AikoColors.dangerRed.withValues(alpha: 0.75),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Dot size reflects total spending for each day this month.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBudgetRow extends StatelessWidget {
  const _CategoryBudgetRow({required this.row});

  final _CategoryUsage row;

  @override
  Widget build(BuildContext context) {
    final ratio = row.budget <= 0
        ? 0.0
        : (row.used / row.budget).clamp(0.0, 1.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _LegendDot(color: row.color, label: row.label),
            const Spacer(),
            Text(
              row.budget > 0
                  ? '\$${row.used.toStringAsFixed(0)} / \$${row.budget.toStringAsFixed(0)}'
                  : '\$${row.used.toStringAsFixed(0)} used',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: row.color.withValues(alpha: 0.12),
            color: row.used > row.budget && row.budget > 0
                ? AikoColors.dangerRed
                : row.color,
          ),
        ),
      ],
    );
  }
}

class _AnalyticsDetailScreen extends StatefulWidget {
  const _AnalyticsDetailScreen({
    required this.kind,
    required this.transactions,
    required this.budgets,
    required this.categories,
  });

  final _AnalyticsWidgetKind kind;
  final List<FinanceTransaction> transactions;
  final List<Budget> budgets;
  final List<Category> categories;

  @override
  State<_AnalyticsDetailScreen> createState() => _AnalyticsDetailScreenState();
}

class _AnalyticsDetailScreenState extends State<_AnalyticsDetailScreen> {
  var _dailyDays = 14;
  var _earningMonths = 6;
  var _categoryRows = 8;
  var _calendarDotScale = 1.25;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titleFor(widget.kind))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _customizationPanel(),
          const SizedBox(height: 16),
          _expandedWidget(),
          const SizedBox(height: 16),
          _detailRows(),
        ],
      ),
    );
  }

  Widget _customizationPanel() {
    return FinanceCard(
      title: 'Customize widget',
      icon: Icons.tune_outlined,
      accentColor: AikoColors.primaryBlue,
      child: switch (widget.kind) {
        _AnalyticsWidgetKind.dailySummary => _ChoiceChips<int>(
          label: 'Range',
          value: _dailyDays,
          options: const {7: '7 days', 14: '14 days', 30: '30 days'},
          onChanged: (value) => setState(() => _dailyDays = value),
        ),
        _AnalyticsWidgetKind.netEarnings => _ChoiceChips<int>(
          label: 'Range',
          value: _earningMonths,
          options: const {4: '4 months', 6: '6 months', 12: '12 months'},
          onChanged: (value) => setState(() => _earningMonths = value),
        ),
        _AnalyticsWidgetKind.categoryBudgets => _ChoiceChips<int>(
          label: 'Categories',
          value: _categoryRows,
          options: const {5: 'Top 5', 8: 'Top 8', 20: 'All'},
          onChanged: (value) => setState(() => _categoryRows = value),
        ),
        _AnalyticsWidgetKind.spendingCalendar => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dot intensity',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Slider(
              value: _calendarDotScale,
              min: 0.75,
              max: 1.75,
              divisions: 4,
              label: '${(_calendarDotScale * 100).round()}%',
              onChanged: (value) => setState(() => _calendarDotScale = value),
            ),
          ],
        ),
      },
    );
  }

  Widget _expandedWidget() {
    return switch (widget.kind) {
      _AnalyticsWidgetKind.dailySummary => _DailySummaryCard(
        transactions: widget.transactions,
        daysToShow: _dailyDays,
      ),
      _AnalyticsWidgetKind.netEarnings => _MonthlyNetEarningsCard(
        transactions: widget.transactions,
        monthsToShow: _earningMonths,
      ),
      _AnalyticsWidgetKind.categoryBudgets => _CategoryBudgetCard(
        transactions: widget.transactions,
        budgets: widget.budgets,
        categories: widget.categories,
        maxRows: _categoryRows,
      ),
      _AnalyticsWidgetKind.spendingCalendar => _SpendingCalendarCard(
        transactions: widget.transactions,
        dotScale: _calendarDotScale,
      ),
    };
  }

  Widget _detailRows() {
    return FinanceCard(
      title: 'Details',
      icon: Icons.notes_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in _detailLines()) ...[
            Text(line, style: Theme.of(context).textTheme.bodyMedium),
            if (line != _detailLines().last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  List<String> _detailLines() {
    final now = DateTime.now();
    final monthlyIncome = _sumTransactionsForMonth(
      widget.transactions,
      DateTime(now.year, now.month, 1),
      TransactionType.income,
    );
    final monthlyExpense = _sumTransactionsForMonth(
      widget.transactions,
      DateTime(now.year, now.month, 1),
      TransactionType.expense,
    );
    return switch (widget.kind) {
      _AnalyticsWidgetKind.dailySummary => [
        'Transactions included: ${widget.transactions.length}',
        'Average daily expense over $_dailyDays days: \$${_averageDailyExpense(widget.transactions, _dateOnly(now), _dailyDays).toStringAsFixed(0)}',
        'Current month expense: \$${monthlyExpense.toStringAsFixed(0)}',
      ],
      _AnalyticsWidgetKind.netEarnings => [
        'Current month income: \$${monthlyIncome.toStringAsFixed(0)}',
        'Current month expense: \$${monthlyExpense.toStringAsFixed(0)}',
        'Current month net: \$${(monthlyIncome - monthlyExpense).toStringAsFixed(0)}',
      ],
      _AnalyticsWidgetKind.categoryBudgets => [
        'Active budgets: ${widget.budgets.where((budget) => budget.status == BudgetStatus.active).length}',
        'Tracked categories: ${widget.categories.length}',
        'Current month expense: \$${monthlyExpense.toStringAsFixed(0)}',
      ],
      _AnalyticsWidgetKind.spendingCalendar => [
        'Month: ${_monthShortLabel(DateTime(now.year, now.month, 1))} ${now.year}',
        'Current month expense: \$${monthlyExpense.toStringAsFixed(0)}',
        'Dot size scale: ${(_calendarDotScale * 100).round()}%',
      ],
    };
  }

  String _titleFor(_AnalyticsWidgetKind kind) {
    return switch (kind) {
      _AnalyticsWidgetKind.dailySummary => 'Daily summary',
      _AnalyticsWidgetKind.netEarnings => 'Net earnings',
      _AnalyticsWidgetKind.categoryBudgets => 'Category budgets',
      _AnalyticsWidgetKind.spendingCalendar => 'Spending calendar',
    };
  }
}

class _ChoiceChips<T> extends StatelessWidget {
  const _ChoiceChips({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in options.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: entry.key == value,
                onSelected: (_) => onChanged(entry.key),
              ),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

class _DailyBucket {
  const _DailyBucket({
    required this.day,
    required this.income,
    required this.expense,
  });

  final DateTime day;
  final double income;
  final double expense;
}

class _MonthlyBucket {
  const _MonthlyBucket({
    required this.month,
    required this.income,
    required this.expense,
  });

  final DateTime month;
  final double income;
  final double expense;
}

class _CategoryUsage {
  const _CategoryUsage({
    required this.categoryId,
    required this.label,
    required this.used,
    required this.budget,
    required this.color,
  });

  final String categoryId;
  final String label;
  final double used;
  final double budget;
  final Color color;
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        Text(value, style: theme.textTheme.titleSmall),
      ],
    );
  }
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

double _sumTransactionsForDay(
  List<FinanceTransaction> transactions,
  DateTime day,
  TransactionType type,
) {
  return transactions
      .where((tx) => tx.type == type && _dateOnly(tx.date) == day)
      .fold<double>(0, (sum, tx) => sum + tx.amount.amount.toDouble());
}

double _sumTransactionsForMonth(
  List<FinanceTransaction> transactions,
  DateTime month,
  TransactionType type,
) {
  return transactions
      .where(
        (tx) =>
            tx.type == type &&
            tx.date.year == month.year &&
            tx.date.month == month.month,
      )
      .fold<double>(0, (sum, tx) => sum + tx.amount.amount.toDouble());
}

double _averageDailyExpense(
  List<FinanceTransaction> transactions,
  DateTime endDay,
  int dayCount,
) {
  final startDay = endDay.subtract(Duration(days: dayCount - 1));
  final total = transactions
      .where((tx) {
        final day = _dateOnly(tx.date);
        return tx.type == TransactionType.expense &&
            !day.isBefore(startDay) &&
            !day.isAfter(endDay);
      })
      .fold<double>(0, (sum, tx) => sum + tx.amount.amount.toDouble());
  return total / dayCount;
}

String _weekdayLabel(DateTime day) {
  return const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][day.weekday - 1];
}

String _monthShortLabel(DateTime month) {
  return const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][month.month - 1];
}

Color _categoryColor(Category? category, String fallbackKey) {
  if (category != null) {
    try {
      final hexColor = category.color.replaceAll('#', '');
      return Color(int.parse('FF$hexColor', radix: 16));
    } catch (_) {
      // Use deterministic fallback below.
    }
  }

  final palette = [
    AikoColors.primaryBlue,
    AikoColors.premiumPurple,
    AikoColors.analyticsTeal,
    AikoColors.warningOrange,
    AikoColors.successGreen,
    AikoColors.dangerRed,
  ];
  return palette[fallbackKey.hashCode.abs() % palette.length];
}
