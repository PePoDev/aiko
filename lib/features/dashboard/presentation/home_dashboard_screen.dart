import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/config/app_config.dart';
import '../../../core/money/money.dart';
import '../../../l10n/domain_labels.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/layout/adaptive_presentation.dart';
import '../../../shared/layout/aiko_adaptive_columns.dart';
import '../../../shared/layout/aiko_breakpoints.dart';
import '../../../shared/widgets/aiko_data_widgets.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../shared/widgets/screen_states.dart';
import '../../../theme/aiko_colors.dart';
import '../../../theme/aiko_status_colors.dart';
import '../../categories/application/category_budget_progress_service.dart';
import '../../categories/domain/category.dart';
import '../../categories/presentation/category_names.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/transaction_form_screen.dart';
import '../application/daily_activity_index.dart';
import '../domain/daily_spending_reaction.dart';
import 'widgets/aiko_spending_reaction_strip.dart';

class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  ConsumerState<HomeDashboardScreen> createState() =>
      _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen> {
  Future<void> _refresh() async {
    await Future.wait([
      ref.refresh(dashboardSummaryProvider.future),
      ref.refresh(transactionsProvider.future),
      ref.refresh(accountsProvider.future),
      ref.refresh(categoriesProvider.future),
    ]);
  }

  /// Reloads the data the summary is built from (a failed load stays failed
  /// until its own provider is rebuilt).
  void _retry() {
    ref
      ..invalidate(transactionsProvider)
      ..invalidate(accountsProvider)
      ..invalidate(categoriesProvider)
      ..invalidate(dashboardSummaryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final l10n = context.l10n;
    final expanded = AikoBreakpoints.isExpanded(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.overview),
        actions: [
          IconButton(
            key: const ValueKey('home-notifications-icon'),
            tooltip: context.l10n.notificationsTitle,
            icon: const Icon(Icons.notifications_none),
            onPressed: () => context.push('/notifications'),
          ),
          IconButton(
            key: const ValueKey('home-settings-icon'),
            tooltip: context.l10n.settingsTitle,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: summaryAsync.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
            children: [AikoScreenState.loading()],
          ),
          error: (error, stack) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
            children: [
              AikoScreenState.error(
                title: l10n.dashboardUnavailable,
                message: l10n.dashboardUnavailableMessage,
                action: FilledButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.retry),
                ),
              ),
            ],
          ),
          data: (_) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, 16, 16, expanded ? 32 : 112),
            children: const [AikoAdaptiveColumns(children: _homeWidgets)],
          ),
        ),
      ),
      // Wide layouts add transactions from the sidebar instead.
      floatingActionButton: expanded ? null : const _QuickAddMenu(),
    );
  }
}

/// The fixed set of widgets shown on the home dashboard, in display order
/// (dealt into two columns on wide screens; see [AikoAdaptiveColumns]).
const _homeWidgets = <Widget>[
  _DailySpendingPanel(),
  _OverviewAnalyticsWidget(kind: _AnalyticsWidgetKind.dailySummary),
  _OverviewAnalyticsWidget(kind: _AnalyticsWidgetKind.netEarnings),
  _OverviewAnalyticsWidget(kind: _AnalyticsWidgetKind.categoryBudgets),
  _OverviewAnalyticsWidget(kind: _AnalyticsWidgetKind.spendingCalendar),
  _CashFlowMappingPanel(),
];

class _DailySpendingPanel extends ConsumerWidget {
  const _DailySpendingPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final summary = ref.watch(dashboardSummaryProvider).value;

    return transactionsAsync.when(
      loading: () => FinanceCard(
        title: context.l10n.dashDailySpending,
        icon: Icons.today_outlined,
        accentColor: AikoColors.warningOrange,
        child: Text(context.l10n.loadingEllipsis),
      ),
      error: (_, _) => FinanceCard(
        title: context.l10n.dashDailySpending,
        icon: Icons.today_outlined,
        accentColor: AikoColors.warningOrange,
        child: Text(context.l10n.unavailable),
      ),
      data: (transactions) {
        final baseCurrency =
            ref.watch(profileProvider).value?.baseCurrency ??
            kDefaultBaseCurrency;
        final used =
            summary?.todaySpending ??
            _dailySpendingUsed(transactions, baseCurrency);

        // Gauge measures today's spend against a daily slice of the weekly
        // safe-to-spend (Safe this week ÷ 7). The arc fills 0→100%; the big
        // number can read past 100% when the day runs over its safe budget.
        // With nothing safe to spend there is no ratio; see
        // [assessDailySpending].
        final safeToSpend = summary?.safeToSpend ?? Money.zero(baseCurrency);
        final (:reaction, :ratio) = assessDailySpending(
          spentToday: used.amount.toDouble(),
          dailySafe: safeToSpend.amount.toDouble() / 7,
          hasIncomeThisMonth: summary?.monthlyIncome.isPositive ?? false,
        );
        final color = reaction.color;

        // Merged-in summaries (formerly separate panels): the weekly safe
        // figure, what's left to save after it, and the month's net cash flow.
        final cashFlow = summary == null
            ? Money.zero(baseCurrency)
            : summary.monthlyIncome - summary.monthlySpending;
        final leftToSave = cashFlow - safeToSpend;

        return FinanceCard(
          title: context.l10n.dashDailySpending,
          icon: Icons.today_outlined,
          accentColor: color,
          // A tab destination: switch to it rather than stacking it.
          onTap: () => context.go('/transactions'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AikoGauge(
                    value: ratio,
                    label: context.l10n.dashUsedToday(used.format()),
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AikoSpendingReactionStrip(reaction: reaction),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _MiniMetric(
                      label: context.l10n.dashSafeThisWeek,
                      value: safeToSpend.format(),
                      color: AikoColors.analyticsTeal,
                    ),
                  ),
                  Expanded(
                    child: _MiniMetric(
                      label: context.l10n.dashLeftToSave,
                      value: leftToSave.format(),
                      color: AikoColors.analyticsTeal,
                    ),
                  ),
                  Expanded(
                    child: _MiniMetric(
                      label: context.l10n.dashCashFlow,
                      value: cashFlow.format(),
                      color: cashFlow.isNegative
                          ? AikoColors.dangerRed
                          : AikoColors.successGreen,
                    ),
                  ),
                ],
              ),
              if (summary?.excludedCurrencies case final excluded?
                  when excluded.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  context.l10n.dashExcludedCurrencies(
                    (excluded.toList()..sort()).join(', '),
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Money _dailySpendingUsed(
    List<FinanceTransaction> transactions,
    String baseCurrency,
  ) {
    final today = DateTime.now();
    String? currency;
    Money? running;
    for (final transaction in transactions) {
      if (!transaction.isExpense) continue;
      if (transaction.status != TransactionStatus.posted) continue;
      if (transaction.date.year != today.year ||
          transaction.date.month != today.month ||
          transaction.date.day != today.day) {
        continue;
      }
      currency ??= transaction.amount.currency;
      if (transaction.amount.currency != currency) continue;
      running = running == null
          ? transaction.amount
          : running + transaction.amount;
    }
    return running ?? Money.zero(baseCurrency);
  }
}

/// One labelled figure in the Daily spending card's summary row.
class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AikoStatusColors.of(context).textFor(color),
          ),
        ),
      ],
    );
  }
}

class _CashFlowMappingPanel extends ConsumerWidget {
  const _CashFlowMappingPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final sankeyAsync = ref.watch(cashFlowSankeyProvider);

    return sankeyAsync.when(
      loading: () => FinanceCard(
        title: l10n.dashCashFlowMapping,
        icon: Icons.bubble_chart_outlined,
        accentColor: AikoColors.analyticsTeal,
        child: Text(l10n.dashLoadingCashFlowMapping),
      ),
      error: (_, _) => FinanceCard(
        title: l10n.dashCashFlowMapping,
        icon: Icons.bubble_chart_outlined,
        accentColor: AikoColors.analyticsTeal,
        child: Text(l10n.dashCashFlowMappingFailed),
      ),
      data: (sankey) {
        if (!sankey.hasActivity) {
          return FinanceCard(
            title: l10n.dashCashFlowMapping,
            icon: Icons.bubble_chart_outlined,
            accentColor: AikoColors.analyticsTeal,
            child: Text(
              l10n.dashCashFlowEmpty,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        final income = sankey.income;
        var outflow = Money.zero(income.currency);
        for (final slice in sankey.outflowByGroup) {
          outflow = outflow + slice.amount;
        }
        final leftOver = income - outflow;
        final flows = <_SankeyFlow>[
          for (final slice in sankey.outflowByGroup)
            _SankeyFlow(
              label: slice.group.label(l10n),
              amount: slice.amount,
              color: _budgetGroupColor(slice.group, theme.colorScheme),
            ),
          if (leftOver.isPositive)
            _SankeyFlow(
              label: l10n.dashLeftOver,
              amount: leftOver,
              color: AikoColors.successGreen,
            ),
        ];

        return FinanceCard(
          title: l10n.dashCashFlowMapping,
          icon: Icons.bubble_chart_outlined,
          accentColor: AikoColors.analyticsTeal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.dashCashFlowMappingDescription,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MiniMetric(
                      label: l10n.income,
                      value: income.format(),
                      color: AikoColors.successGreen,
                    ),
                  ),
                  Expanded(
                    child: _MiniMetric(
                      label: l10n.dashMoneyOut,
                      value: outflow.format(),
                      color: AikoColors.dangerRed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ExcludeSemantics(
                child: SizedBox(
                  height: 140,
                  child: CustomPaint(
                    painter: _SankeyPainter(
                      income: income.amount.toDouble(),
                      flows: [
                        for (final flow in flows)
                          (flow.amount.amount.toDouble(), flow.color),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              for (final flow in flows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: flow.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          flow.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        flow.amount.format(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// One destination of this month's money in the Cash flow mapping panel.
class _SankeyFlow {
  const _SankeyFlow({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final Money amount;
  final Color color;
}

Color _budgetGroupColor(CategoryBudgetGroup group, ColorScheme scheme) =>
    switch (group) {
      CategoryBudgetGroup.needs => AikoColors.warningOrange,
      CategoryBudgetGroup.wants => AikoColors.deepBlue,
      CategoryBudgetGroup.savings => AikoColors.analyticsTeal,
      CategoryBudgetGroup.debt => AikoColors.dangerRed,
      CategoryBudgetGroup.investment => AikoColors.premiumPurple,
      CategoryBudgetGroup.tax => AikoColors.primaryBlue,
      CategoryBudgetGroup.business => AikoColors.softBlue,
      CategoryBudgetGroup.custom => scheme.outline,
    };

/// Income on the left flowing into each destination on the right, every band
/// as tall as its amount. When more went out than came in, the income band is
/// shorter and the ribbons widen towards the right.
class _SankeyPainter extends CustomPainter {
  const _SankeyPainter({required this.income, required this.flows});

  final double income;

  /// Amount and color of each destination, top to bottom.
  final List<(double, Color)> flows;

  static const _nodeWidth = 8.0;
  static const _gap = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final totalOut = flows.fold<double>(0, (sum, flow) => sum + flow.$1);
    final scaleBase = income > totalOut ? income : totalOut;
    if (scaleBase <= 0 || flows.isEmpty) return;

    final usable = size.height - _gap * (flows.length - 1);
    final unit = usable / scaleBase;
    final leftHeight = income * unit;
    final leftTop = (size.height - leftHeight) / 2;

    canvas.drawRect(
      Rect.fromLTWH(0, leftTop, _nodeWidth, leftHeight),
      Paint()..color = AikoColors.successGreen,
    );

    var leftY = leftTop;
    var rightY = 0.0;
    for (final (amount, color) in flows) {
      final rightHeight = amount * unit;
      final leftShare = totalOut <= 0 ? 0.0 : leftHeight * amount / totalOut;
      canvas.drawRect(
        Rect.fromLTWH(size.width - _nodeWidth, rightY, _nodeWidth, rightHeight),
        Paint()..color = color,
      );
      _drawRibbon(
        canvas,
        size: size,
        fromTop: leftY,
        fromHeight: leftShare,
        toTop: rightY,
        toHeight: rightHeight,
        toColor: color,
      );
      leftY += leftShare;
      rightY += rightHeight + _gap;
    }
  }

  void _drawRibbon(
    Canvas canvas, {
    required Size size,
    required double fromTop,
    required double fromHeight,
    required double toTop,
    required double toHeight,
    required Color toColor,
  }) {
    const left = _nodeWidth;
    final right = size.width - _nodeWidth;
    final span = right - left;
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          AikoColors.successGreen.withValues(alpha: 0.35),
          toColor.withValues(alpha: 0.35),
        ],
      ).createShader(Rect.fromLTRB(left, 0, right, size.height));

    final path = Path()
      ..moveTo(left, fromTop)
      ..cubicTo(
        left + span * 0.5,
        fromTop,
        left + span * 0.5,
        toTop,
        right,
        toTop,
      )
      ..lineTo(right, toTop + toHeight)
      ..cubicTo(
        left + span * 0.5,
        toTop + toHeight,
        left + span * 0.5,
        fromTop + fromHeight,
        left,
        fromTop + fromHeight,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SankeyPainter oldDelegate) =>
      oldDelegate.income != income || !listEquals(oldDelegate.flows, flows);
}

class _QuickAddMenu extends StatelessWidget {
  const _QuickAddMenu();

  @override
  Widget build(BuildContext context) {
    // Above the shell (like the Transactions tab's button), so the bottom bar
    // can't switch tabs away from an unsaved form.
    return FloatingActionButton(
      heroTag: 'quick-add-main',
      tooltip: context.l10n.newTransaction,
      onPressed: () => openAikoPage<void>(
        context,
        const TransactionFormScreen(),
        rootNavigator: true,
      ),
      child: const Icon(Icons.add),
    );
  }
}

class _OverviewAnalyticsWidget extends ConsumerWidget {
  const _OverviewAnalyticsWidget({required this.kind});

  final _AnalyticsWidgetKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return transactionsAsync.when(
      loading: () => FinanceCard(
        title: kind.title(context.l10n),
        icon: Icons.bar_chart_outlined,
        child: Text(context.l10n.dashLoadingAnalytics),
      ),
      error: (error, stack) => FinanceCard(
        title: kind.title(context.l10n),
        icon: Icons.bar_chart_outlined,
        child: Text(context.l10n.dashAnalyticsFailed),
      ),
      data: (transactions) {
        final categories =
            categoriesAsync.whenOrNull(data: (items) => items) ??
            const <Category>[];
        final currency =
            ref.watch(profileProvider).value?.baseCurrency ??
            kDefaultBaseCurrency;

        return switch (kind) {
          _AnalyticsWidgetKind.dailySummary => _DailySummaryCard(
            transactions: transactions,
            currency: currency,
            showPeriodSelector: true,
            onTap: () => _openAnalyticsDetail(
              context,
              kind: kind,
              transactions: transactions,
              categories: categories,
              currency: currency,
            ),
          ),
          _AnalyticsWidgetKind.netEarnings => _MonthlyNetEarningsCard(
            transactions: transactions,
            currency: currency,
            onTap: () => _openAnalyticsDetail(
              context,
              kind: kind,
              transactions: transactions,
              categories: categories,
              currency: currency,
            ),
          ),
          _AnalyticsWidgetKind.categoryBudgets => _CategoryBudgetCard(
            transactions: transactions,
            categories: categories,
            currency: currency,
            onTap: () => _openAnalyticsDetail(
              context,
              kind: kind,
              transactions: transactions,
              categories: categories,
              currency: currency,
            ),
          ),
          _AnalyticsWidgetKind.spendingCalendar => _SpendingCalendarCard(
            transactions: transactions,
            currency: currency,
            onTap: () => _openAnalyticsDetail(
              context,
              kind: kind,
              transactions: transactions,
              categories: categories,
              currency: currency,
            ),
          ),
        };
      },
    );
  }

  void _openAnalyticsDetail(
    BuildContext context, {
    required _AnalyticsWidgetKind kind,
    required List<FinanceTransaction> transactions,
    required List<Category> categories,
    required String currency,
  }) {
    openAikoPage<void>(
      context,
      _AnalyticsDetailScreen(
        kind: kind,
        transactions: transactions,
        categories: categories,
        currency: currency,
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

extension on _AnalyticsWidgetKind {
  String title(AppLocalizations l10n) {
    return switch (this) {
      _AnalyticsWidgetKind.dailySummary => l10n.dashDailySummary,
      _AnalyticsWidgetKind.netEarnings => l10n.dashNetEarnings,
      _AnalyticsWidgetKind.categoryBudgets => l10n.dashCategoryBudgets,
      _AnalyticsWidgetKind.spendingCalendar => l10n.dashSpendingCalendar,
    };
  }
}

class _DailySummaryCard extends StatefulWidget {
  const _DailySummaryCard({
    required this.transactions,
    required this.currency,
    this.daysToShow = 7,
    this.showPeriodSelector = false,
    this.onTap,
  });

  final List<FinanceTransaction> transactions;
  final int daysToShow;
  final String currency;

  /// Home shows a "Last 7 days / Last 30 days" pill; the detail screen drives
  /// the range with its own chips, so it leaves this off and passes
  /// [daysToShow].
  final bool showPeriodSelector;
  final VoidCallback? onTap;

  @override
  State<_DailySummaryCard> createState() => _DailySummaryCardState();
}

class _DailySummaryCardState extends State<_DailySummaryCard> {
  late int _period = widget.daysToShow;

  /// Per-day totals, rebuilt only when the ledger changes (not when the
  /// period changes or the card rebuilds).
  late DailyActivityIndex _index = DailyActivityIndex.build(
    widget.transactions,
  );

  @override
  void didUpdateWidget(covariant _DailySummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.transactions, widget.transactions)) {
      _index = DailyActivityIndex.build(widget.transactions);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onTap;
    final currency = widget.currency;
    final daysToShow = widget.showPeriodSelector ? _period : widget.daysToShow;
    final today = _dateOnly(DateTime.now());
    final buckets = <_DailyBucket>[];
    for (var offset = daysToShow - 1; offset >= 0; offset--) {
      final day = DateTime(today.year, today.month, today.day - offset);
      buckets.add(
        _DailyBucket(
          day: day,
          income: _index.incomeOn(day),
          expense: _index.expenseOn(day),
        ),
      );
    }
    final maxValue = buckets.fold<double>(
      0,
      (max, bucket) =>
          [max, bucket.income, bucket.expense].reduce((a, b) => a > b ? a : b),
    );
    final sevenDayAverage = _index.averageDailyExpense(today, 7);
    final thirtyDayAverage = _index.averageDailyExpense(today, 30);

    return FinanceCard(
      title: context.l10n.dashDailySummary,
      icon: Icons.bar_chart_outlined,
      accentColor: AikoColors.analyticsTeal,
      trailing: widget.showPeriodSelector
          ? _PeriodPill(
              days: _period,
              onChanged: (value) => setState(() => _period = value),
            )
          : null,
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
                        // Weekday letters read well for a week; for longer
                        // ranges they'd collide, so show the day number on
                        // every 5th bar instead.
                        final day = buckets[index].day;
                        final label = buckets.length <= 7
                            ? _weekdayLabel(day)
                            : (index == 0 || day.day % 5 == 0)
                            ? '${day.day}'
                            : '';
                        if (label.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            label,
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
              _LegendDot(
                color: AikoColors.successGreen,
                label: context.l10n.transactionTypeIncome,
              ),
              const SizedBox(width: 16),
              _LegendDot(
                color: AikoColors.dangerRed,
                label: context.l10n.transactionTypeExpense,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  context.l10n.dashSevenDayAvg(
                    _formatAmount(sevenDayAverage, currency),
                  ),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _AverageSpendingBox(
            sevenDay: _formatAmount(sevenDayAverage, currency),
            thirtyDay: _formatAmount(thirtyDayAverage, currency),
          ),
        ],
      ),
    );
  }
}

/// Period selector pill shown in the Daily summary header (the last 7 or 30
/// days, ending today).
class _PeriodPill extends StatelessWidget {
  const _PeriodPill({required this.days, required this.onChanged});

  final int days;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<int>(
      initialValue: days,
      onSelected: onChanged,
      itemBuilder: (context) => [
        PopupMenuItem(value: 7, child: Text(context.l10n.dashLastDays(7))),
        PopupMenuItem(value: 30, child: Text(context.l10n.dashLastDays(30))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                context.l10n.dashLastDays(days),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, size: 18),
          ],
        ),
      ),
    );
  }
}

/// Tinted summary box with a trend badge, matching the dashboard design.
class _AverageSpendingBox extends StatelessWidget {
  const _AverageSpendingBox({required this.sevenDay, required this.thirtyDay});

  final String sevenDay;
  final String thirtyDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AikoColors.successGreen.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.trending_up,
              size: 16,
              color: AikoColors.successGreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.dashAverageSpending,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.dashSevenDaysPerDay(sevenDay),
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  context.l10n.dashThirtyDaysPerDay(thirtyDay),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyNetEarningsCard extends StatelessWidget {
  const _MonthlyNetEarningsCard({
    required this.transactions,
    required this.currency,
    this.monthsToShow = 4,
    this.onTap,
  });

  final List<FinanceTransaction> transactions;
  final int monthsToShow;
  final String currency;
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
      title: context.l10n.dashNetEarnings,
      icon: Icons.stacked_bar_chart_outlined,
      accentColor: AikoColors.deepBlue,
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
              _LegendDot(
                color: AikoColors.successGreen,
                label: context.l10n.transactionTypeIncome,
              ),
              const SizedBox(width: 16),
              _LegendDot(
                color: AikoColors.dangerRed,
                label: context.l10n.transactionTypeExpense,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.dashThisMonthNet(_formatAmount(net, currency)),
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
    required this.categories,
    required this.currency,
    this.maxRows = 5,
    this.onTap,
  });

  final List<FinanceTransaction> transactions;
  final List<Category> categories;
  final int maxRows;
  final String currency;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthExpenses = transactions
        .where(
          (tx) =>
              tx.type == TransactionType.expense &&
              tx.status != TransactionStatus.voided &&
              tx.status != TransactionStatus.archived &&
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
    // This chart is the month's spending, so only monthly budgets (with any
    // rollover) compare with it.
    const progressService = CategoryBudgetProgressService();
    final budgetByCategory = {
      for (final category in categories)
        if (category.hasBudget &&
            category.budgetPeriod == CategoryBudgetPeriod.monthly)
          category.id: progressService
              .progressFor(category, transactions, asOf: now)
              .limit!
              .amount
              .toDouble(),
    };
    final rows =
        usageByCategory.entries
            .map(
              (entry) => _CategoryUsage(
                categoryId: entry.key,
                label:
                    categoryById[entry.key]?.displayName(context.l10n) ??
                    context.l10n.uncategorized,
                used: entry.value,
                budget: budgetByCategory[entry.key] ?? 0,
                color: _categoryColor(categoryById[entry.key], entry.key),
              ),
            )
            .toList()
          ..sort((a, b) => b.used.compareTo(a.used));

    final chartRows = rows.isEmpty
        ? [
            _CategoryUsage(
              categoryId: 'none',
              label: context.l10n.dashNoSpending,
              used: 1,
              budget: 0,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ]
        : rows;
    final chartTotal = chartRows
        .take(6)
        .fold<double>(0, (sum, row) => sum + row.used);

    return FinanceCard(
      title: context.l10n.dashCategoryBudgets,
      icon: Icons.pie_chart_outline,
      accentColor: AikoColors.premiumPurple,
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
                      // Compact ("฿1.2K") so it fits inside the slice; slivers
                      // too thin for a label go without.
                      title:
                          row.categoryId == 'none' ||
                              row.used < chartTotal * 0.08
                          ? ''
                          : NumberFormat.compactSimpleCurrency(
                              name: currency,
                            ).format(row.used),
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
              context.l10n.dashNoCategorySpending,
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            for (final row in rows.take(maxRows)) ...[
              _CategoryBudgetRow(row: row, currency: currency),
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
    required this.currency,
    this.dotScale = 1,
    this.onTap,
  });

  final List<FinanceTransaction> transactions;
  final String currency;
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
    final l10n = context.l10n;
    final dayStyle = Theme.of(context).textTheme.labelSmall;
    // Each cell is as tall as its day number at the current text size plus the
    // largest dot, so larger text grows the rows instead of overflowing them.
    final dotArea = 16 * dotScale;
    final dayTextHeight = MediaQuery.textScalerOf(
      context,
    ).scale((dayStyle?.fontSize ?? 11) * (dayStyle?.height ?? 1.4));
    final cellExtent = dayTextHeight + 4 + dotArea + 4;

    return FinanceCard(
      title: context.l10n.dashSpendingCalendar,
      icon: Icons.calendar_month_outlined,
      accentColor: AikoColors.warningOrange,
      onTap: onTap,
      child: Column(
        children: [
          Row(
            children: [
              // 2024-01-07 was a Sunday: Sunday-first narrow day names.
              for (final label in [
                for (var i = 0; i < 7; i++)
                  DateFormat('EEEEE').format(DateTime(2024, 1, 7 + i)),
              ])
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              mainAxisExtent: cellExtent,
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
              final date = DateFormat.MMMMd().format(
                DateTime(now.year, now.month, day),
              );

              return Semantics(
                container: true,
                excludeSemantics: true,
                label: spend <= 0
                    ? l10n.dashCalendarDayNoSpending(date)
                    : l10n.dashCalendarDaySpent(
                        date,
                        _formatAmount(spend, currency),
                      ),
                // Safety net for extreme text sizes on narrow screens.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$day', style: dayStyle),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: dotArea,
                        height: dotArea,
                        child: Center(
                          child: Container(
                            width: dotSize,
                            height: dotSize,
                            decoration: BoxDecoration(
                              color: AikoColors.dangerRed.withValues(
                                alpha: 0.75,
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              context.l10n.dashCalendarHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBudgetRow extends StatelessWidget {
  const _CategoryBudgetRow({required this.row, required this.currency});

  final _CategoryUsage row;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final ratio = row.budget <= 0
        ? 0.0
        : (row.used / row.budget).clamp(0.0, 1.0).toDouble();
    final textTheme = Theme.of(context).textTheme;
    final used = _formatAmount(row.used, currency);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: row.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              // Long (e.g. Thai) category names shrink to an ellipsis instead
              // of pushing the amount off the card.
              Expanded(
                child: Text(
                  row.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelMedium,
                ),
              ),
              const SizedBox(width: 8),
              // The amount keeps its natural width, up to most of the row.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth * 0.65,
                ),
                child: Text(
                  row.budget > 0
                      ? '$used / ${_formatAmount(row.budget, currency)}'
                      : context.l10n.dashAmountUsed(used),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: textTheme.labelMedium,
                ),
              ),
            ],
          ),
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
    required this.categories,
    required this.currency,
  });

  final _AnalyticsWidgetKind kind;
  final List<FinanceTransaction> transactions;
  final List<Category> categories;
  final String currency;

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
      appBar: AppBar(title: Text(widget.kind.title(context.l10n))),
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
    final l10n = context.l10n;
    return FinanceCard(
      title: context.l10n.dashCustomizeWidget,
      icon: Icons.tune_outlined,
      accentColor: AikoColors.primaryBlue,
      child: switch (widget.kind) {
        _AnalyticsWidgetKind.dailySummary => _ChoiceChips<int>(
          label: context.l10n.dashRange,
          value: _dailyDays,
          options: {
            for (final days in const [7, 14, 30]) days: l10n.daysCount(days),
          },
          onChanged: (value) => setState(() => _dailyDays = value),
        ),
        _AnalyticsWidgetKind.netEarnings => _ChoiceChips<int>(
          label: context.l10n.dashRange,
          value: _earningMonths,
          options: {
            for (final months in const [4, 6, 12])
              months: l10n.monthsCount(months),
          },
          onChanged: (value) => setState(() => _earningMonths = value),
        ),
        _AnalyticsWidgetKind.categoryBudgets => _ChoiceChips<int>(
          label: context.l10n.categoriesTab,
          value: _categoryRows,
          options: {
            5: l10n.topCount(5),
            8: l10n.topCount(8),
            20: l10n.txFilterAll,
          },
          onChanged: (value) => setState(() => _categoryRows = value),
        ),
        _AnalyticsWidgetKind.spendingCalendar => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.dashDotIntensity,
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
        currency: widget.currency,
      ),
      _AnalyticsWidgetKind.netEarnings => _MonthlyNetEarningsCard(
        transactions: widget.transactions,
        monthsToShow: _earningMonths,
        currency: widget.currency,
      ),
      _AnalyticsWidgetKind.categoryBudgets => _CategoryBudgetCard(
        transactions: widget.transactions,
        categories: widget.categories,
        maxRows: _categoryRows,
        currency: widget.currency,
      ),
      _AnalyticsWidgetKind.spendingCalendar => _SpendingCalendarCard(
        transactions: widget.transactions,
        currency: widget.currency,
        dotScale: _calendarDotScale,
      ),
    };
  }

  Widget _detailRows() {
    final lines = _detailLines();
    return FinanceCard(
      title: context.l10n.dashDetails,
      icon: Icons.notes_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Text(lines[i], style: Theme.of(context).textTheme.bodyMedium),
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
    final l10n = context.l10n;
    String amount(double value) => _formatAmount(value, widget.currency);
    return switch (widget.kind) {
      _AnalyticsWidgetKind.dailySummary => [
        l10n.dashDetailTransactionsIncluded(widget.transactions.length),
        l10n.dashDetailAverageDaily(
          _dailyDays,
          amount(
            DailyActivityIndex.build(
              widget.transactions,
            ).averageDailyExpense(_dateOnly(now), _dailyDays),
          ),
        ),
        l10n.dashDetailMonthExpense(amount(monthlyExpense)),
      ],
      _AnalyticsWidgetKind.netEarnings => [
        l10n.dashDetailMonthIncome(amount(monthlyIncome)),
        l10n.dashDetailMonthExpense(amount(monthlyExpense)),
        l10n.dashDetailMonthNet(amount(monthlyIncome - monthlyExpense)),
      ],
      _AnalyticsWidgetKind.categoryBudgets => [
        l10n.dashDetailBudgetedCategories(
          widget.categories.where((c) => c.hasBudget).length,
        ),
        l10n.dashDetailTrackedCategories(widget.categories.length),
        l10n.dashDetailMonthExpense(amount(monthlyExpense)),
      ],
      _AnalyticsWidgetKind.spendingCalendar => [
        l10n.dashDetailMonth(DateFormat.yMMM().format(now)),
        l10n.dashDetailMonthExpense(amount(monthlyExpense)),
        l10n.dashDetailDotScale((_calendarDotScale * 100).round()),
      ],
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

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

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

/// [value] in [currency], formatted like any other [Money].
String _formatAmount(double value, String currency) => Money(
  amount: Decimal.parse(value.toStringAsFixed(2)),
  currency: currency,
).format();

String _weekdayLabel(DateTime day) => DateFormat('EEEEE').format(day);

String _monthShortLabel(DateTime month) => DateFormat.MMM().format(month);

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
