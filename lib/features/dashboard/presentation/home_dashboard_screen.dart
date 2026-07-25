import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/config/app_config.dart';
import '../../../core/money/money.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/aiko_data_widgets.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../shared/widgets/screen_states.dart';
import '../../../theme/aiko_colors.dart';
import '../../categories/domain/category.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/transaction_form_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.overview),
        actions: [
          IconButton(
            key: const ValueKey('home-notifications-icon'),
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_none),
            onPressed: () => context.push('/notifications'),
          ),
          IconButton(
            key: const ValueKey('home-settings-icon'),
            tooltip: 'Settings',
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
                message: '${l10n.dashboardUnavailableMessage}\n$error',
              ),
            ],
          ),
          data: (_) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
            children: [
              for (var i = 0; i < _homeWidgets.length; i++)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 16),
                  child: _homeWidgets[i],
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: const _QuickAddMenu(),
    );
  }
}

/// The fixed set of widgets shown on the home dashboard, in display order.
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
      loading: () => const FinanceCard(
        title: 'Daily spending',
        icon: Icons.today_outlined,
        accentColor: AikoColors.warningOrange,
        child: Text('Loading...'),
      ),
      error: (_, _) => const FinanceCard(
        title: 'Daily spending',
        icon: Icons.today_outlined,
        accentColor: AikoColors.warningOrange,
        child: Text('Unavailable'),
      ),
      data: (transactions) {
        final baseCurrency =
            ref.watch(profileProvider).value?.baseCurrency ??
            kDefaultBaseCurrency;
        final used = _dailySpendingUsed(transactions, baseCurrency);

        // Gauge measures today's spend against a daily slice of the weekly
        // safe-to-spend (Safe this week ÷ 7). The arc fills 0→100%; the big
        // number can read past 100% when the day runs over its safe budget.
        final safeToSpend = summary?.safeToSpend ?? Money.zero(baseCurrency);
        final dailySafe = safeToSpend.amount.toDouble() / 7;
        final ratio = dailySafe > 0 ? used.amount.toDouble() / dailySafe : 0.0;
        final reaction = DailySpendingReaction.fromRatio(ratio);
        final color = reaction.color;

        // Merged-in summaries (formerly separate panels): the weekly safe
        // figure, what's left to save after it, and the month's net cash flow.
        final cashFlow = summary == null
            ? Money.zero(baseCurrency)
            : summary.monthlyIncome - summary.monthlySpending;
        final leftToSave = cashFlow - safeToSpend;

        return FinanceCard(
          title: 'Daily spending',
          icon: Icons.today_outlined,
          accentColor: color,
          onTap: () => context.push('/transactions'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AikoGauge(
                    value: ratio,
                    label: '${used.format()} today',
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
                      label: 'Safe this week',
                      value: safeToSpend.format(),
                      color: AikoColors.analyticsTeal,
                    ),
                  ),
                  Expanded(
                    child: _MiniMetric(
                      label: 'Left to save',
                      value: leftToSave.format(),
                      color: AikoColors.analyticsTeal,
                    ),
                  ),
                  Expanded(
                    child: _MiniMetric(
                      label: 'Cash flow',
                      value: cashFlow.format(),
                      color: cashFlow.isNegative
                          ? AikoColors.dangerRed
                          : AikoColors.successGreen,
                    ),
                  ),
                ],
              ),
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
            color: color,
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
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final summaryAsync = ref.watch(dashboardSummaryProvider);

    return summaryAsync.when(
      loading: () => const FinanceCard(
        title: 'Cash flow mapping',
        icon: Icons.bubble_chart_outlined,
        accentColor: AikoColors.analyticsTeal,
        child: Text('Loading cash flow mapping...'),
      ),
      error: (_, _) => const FinanceCard(
        title: 'Cash flow mapping',
        icon: Icons.bubble_chart_outlined,
        accentColor: AikoColors.analyticsTeal,
        child: Text('Unable to load cash flow mapping right now.'),
      ),
      data: (summary) {
        var totalIncome = summary.monthlyIncome.amount.toDouble();
        if (totalIncome <= 0) totalIncome = 5000.0;
        var totalSpending = summary.monthlySpending.amount.toDouble();
        if (totalSpending <= 0) totalSpending = 2500.0;

        var bills = totalIncome * 0.45;
        var discretionary = totalIncome * 0.35;
        var savings = totalIncome * 0.20;

        if (totalSpending > totalIncome) {
          bills = totalIncome * 0.55;
          discretionary = totalIncome * 0.40;
          savings = totalIncome * 0.05;
        }

        final baseCurrency =
            ref.watch(profileProvider).value?.baseCurrency ??
            kDefaultBaseCurrency;
        final currencyFormat = NumberFormat.simpleCurrency(name: baseCurrency);

        return FinanceCard(
          title: 'Cash flow mapping',
          icon: Icons.bubble_chart_outlined,
          accentColor: AikoColors.analyticsTeal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A visual mapping of your monthly income flows into bills, discretionary spending, and savings cushions.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 4,
                          height: 40,
                          color: AikoColors.successGreen,
                        ),
                        const SizedBox(height: 6),
                        Text(l10n.income, style: textTheme.bodySmall),
                        Text(
                          currencyFormat.format(totalIncome),
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: SizedBox(
                      height: 150,
                      child: CustomPaint(
                        painter: _SankeyPainter(
                          billsRatio: bills / totalIncome,
                          discretionaryRatio: discretionary / totalIncome,
                          savingsRatio: savings / totalIncome,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _FlowAmount(
                          label: 'Fixed Bills',
                          amount: currencyFormat.format(bills),
                          color: AikoColors.warningOrange,
                        ),
                        const SizedBox(height: 20),
                        _FlowAmount(
                          label: 'Discretionary',
                          amount: currencyFormat.format(discretionary),
                          color: AikoColors.deepBlue,
                        ),
                        const SizedBox(height: 20),
                        _FlowAmount(
                          label: 'Savings',
                          amount: currencyFormat.format(savings),
                          color: AikoColors.analyticsTeal,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FlowAmount extends StatelessWidget {
  const _FlowAmount({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: textTheme.bodySmall),
        Text(
          amount,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _SankeyPainter extends CustomPainter {
  const _SankeyPainter({
    required this.billsRatio,
    required this.discretionaryRatio,
    required this.savingsRatio,
  });

  final double billsRatio;
  final double discretionaryRatio;
  final double savingsRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final leftHeight = size.height - 40.0;
    final rightGap = 20.0;
    final rightTotalAvailableHeight = size.height - (2 * rightGap) - 20.0;
    final billsHeight = rightTotalAvailableHeight * billsRatio;
    final discretionaryHeight = rightTotalAvailableHeight * discretionaryRatio;
    final savingsHeight = rightTotalAvailableHeight * savingsRatio;
    final discretionaryYStart = 10.0 + billsHeight + rightGap;
    final savingsYStart = discretionaryYStart + discretionaryHeight + rightGap;

    _drawFlow(
      canvas,
      fromYStart: 20,
      fromHeight: leftHeight * billsRatio,
      toYStart: 10,
      toHeight: billsHeight,
      size: size,
      fromColor: AikoColors.successGreen,
      toColor: AikoColors.warningOrange,
    );
    _drawFlow(
      canvas,
      fromYStart: 20 + (leftHeight * billsRatio),
      fromHeight: leftHeight * discretionaryRatio,
      toYStart: discretionaryYStart,
      toHeight: discretionaryHeight,
      size: size,
      fromColor: AikoColors.successGreen,
      toColor: AikoColors.deepBlue,
    );
    _drawFlow(
      canvas,
      fromYStart: 20 + (leftHeight * (billsRatio + discretionaryRatio)),
      fromHeight: leftHeight * savingsRatio,
      toYStart: savingsYStart,
      toHeight: savingsHeight,
      size: size,
      fromColor: AikoColors.successGreen,
      toColor: AikoColors.analyticsTeal,
    );
  }

  void _drawFlow(
    Canvas canvas, {
    required double fromYStart,
    required double fromHeight,
    required double toYStart,
    required double toHeight,
    required Size size,
    required Color fromColor,
    required Color toColor,
  }) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          fromColor.withValues(alpha: 0.35),
          toColor.withValues(alpha: 0.35),
        ],
      ).createShader(Rect.fromLTRB(0, 0, size.width, 0))
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, fromYStart)
      ..cubicTo(
        size.width * 0.4,
        fromYStart,
        size.width * 0.6,
        toYStart,
        size.width,
        toYStart,
      )
      ..lineTo(size.width, toYStart + toHeight)
      ..cubicTo(
        size.width * 0.6,
        toYStart + toHeight,
        size.width * 0.4,
        fromYStart + fromHeight,
        0,
        fromYStart + fromHeight,
      )
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SankeyPainter oldDelegate) {
    return oldDelegate.billsRatio != billsRatio ||
        oldDelegate.discretionaryRatio != discretionaryRatio ||
        oldDelegate.savingsRatio != savingsRatio;
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

class _OverviewAnalyticsWidget extends ConsumerWidget {
  const _OverviewAnalyticsWidget({required this.kind});

  final _AnalyticsWidgetKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return transactionsAsync.when(
      loading: () => FinanceCard(
        title: kind.title,
        icon: Icons.bar_chart_outlined,
        child: Text('Loading transaction analytics...'),
      ),
      error: (error, stack) => FinanceCard(
        title: kind.title,
        icon: Icons.bar_chart_outlined,
        child: Text('Unable to load transaction analytics right now.'),
      ),
      data: (transactions) {
        final categories =
            categoriesAsync.whenOrNull(data: (items) => items) ??
            const <Category>[];
        final baseCurrency =
            ref.watch(profileProvider).value?.baseCurrency ??
            kDefaultBaseCurrency;
        final symbol = NumberFormat.simpleCurrency(
          name: baseCurrency,
        ).currencySymbol;

        return switch (kind) {
          _AnalyticsWidgetKind.dailySummary => _DailySummaryCard(
            transactions: transactions,
            currencySymbol: symbol,
            showPeriodSelector: true,
            onTap: () => _openAnalyticsDetail(
              context,
              kind: kind,
              transactions: transactions,
              categories: categories,
              currencySymbol: symbol,
            ),
          ),
          _AnalyticsWidgetKind.netEarnings => _MonthlyNetEarningsCard(
            transactions: transactions,
            currencySymbol: symbol,
            onTap: () => _openAnalyticsDetail(
              context,
              kind: kind,
              transactions: transactions,
              categories: categories,
              currencySymbol: symbol,
            ),
          ),
          _AnalyticsWidgetKind.categoryBudgets => _CategoryBudgetCard(
            transactions: transactions,
            categories: categories,
            currencySymbol: symbol,
            onTap: () => _openAnalyticsDetail(
              context,
              kind: kind,
              transactions: transactions,
              categories: categories,
              currencySymbol: symbol,
            ),
          ),
          _AnalyticsWidgetKind.spendingCalendar => _SpendingCalendarCard(
            transactions: transactions,
            onTap: () => _openAnalyticsDetail(
              context,
              kind: kind,
              transactions: transactions,
              categories: categories,
              currencySymbol: symbol,
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
    required String currencySymbol,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _AnalyticsDetailScreen(
          kind: kind,
          transactions: transactions,
          categories: categories,
          currencySymbol: currencySymbol,
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

extension on _AnalyticsWidgetKind {
  String get title {
    return switch (this) {
      _AnalyticsWidgetKind.dailySummary => 'Daily summary',
      _AnalyticsWidgetKind.netEarnings => 'Net earnings',
      _AnalyticsWidgetKind.categoryBudgets => 'Category budgets',
      _AnalyticsWidgetKind.spendingCalendar => 'Spending calendar',
    };
  }
}

class _DailySummaryCard extends StatefulWidget {
  const _DailySummaryCard({
    required this.transactions,
    this.daysToShow = 7,
    this.currencySymbol = r'$',
    this.showPeriodSelector = false,
    this.onTap,
  });

  final List<FinanceTransaction> transactions;
  final int daysToShow;
  final String currencySymbol;

  /// Home shows a "This week / This month" pill; the detail screen drives the
  /// range with its own chips, so it leaves this off and passes [daysToShow].
  final bool showPeriodSelector;
  final VoidCallback? onTap;

  @override
  State<_DailySummaryCard> createState() => _DailySummaryCardState();
}

class _DailySummaryCardState extends State<_DailySummaryCard> {
  late int _period = widget.daysToShow;

  @override
  Widget build(BuildContext context) {
    final transactions = widget.transactions;
    final onTap = widget.onTap;
    final symbol = widget.currencySymbol;
    final daysToShow = widget.showPeriodSelector ? _period : widget.daysToShow;
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
              const _LegendDot(color: AikoColors.successGreen, label: 'Income'),
              const SizedBox(width: 16),
              const _LegendDot(color: AikoColors.dangerRed, label: 'Expense'),
              const Spacer(),
              Text(
                '7-day avg $symbol${sevenDayAverage.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _AverageSpendingBox(
            sevenDay: '$symbol${sevenDayAverage.toStringAsFixed(0)}',
            thirtyDay: '$symbol${thirtyDayAverage.toStringAsFixed(0)}',
          ),
        ],
      ),
    );
  }
}

/// Period selector pill shown in the Daily summary header (week / month).
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
      itemBuilder: (context) => const [
        PopupMenuItem(value: 7, child: Text('This week')),
        PopupMenuItem(value: 30, child: Text('This month')),
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
            Text(
              days <= 7 ? 'This week' : 'This month',
              style: theme.textTheme.labelLarge,
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
                  'Average spending',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '7 days: $sevenDay per day',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  '30 days: $thirtyDay per day',
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
    this.monthsToShow = 4,
    this.currencySymbol = r'$',
    this.onTap,
  });

  final List<FinanceTransaction> transactions;
  final int monthsToShow;
  final String currencySymbol;
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
            'This month net: $currencySymbol${net.toStringAsFixed(0)}',
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
    this.maxRows = 5,
    this.currencySymbol = r'$',
    this.onTap,
  });

  final List<FinanceTransaction> transactions;
  final List<Category> categories;
  final int maxRows;
  final String currencySymbol;
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
      for (final category in categories)
        if (category.monthlyLimit != null)
          category.id: category.monthlyLimit!.amount.toDouble(),
    };
    final rows =
        usageByCategory.entries
            .map(
              (entry) => _CategoryUsage(
                categoryId: entry.key,
                label: categoryById[entry.key]?.name ?? 'Uncategorized',
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
              label: 'No spending',
              used: 1,
              budget: 0,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ]
        : rows;

    return FinanceCard(
      title: 'Category budgets',
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
                      title: row.label == 'No spending'
                          ? ''
                          : '$currencySymbol${row.used.toStringAsFixed(0)}',
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
              _CategoryBudgetRow(row: row, currencySymbol: currencySymbol),
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
  const _CategoryBudgetRow({required this.row, this.currencySymbol = r'$'});

  final _CategoryUsage row;
  final String currencySymbol;

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
                  ? '$currencySymbol${row.used.toStringAsFixed(0)} / $currencySymbol${row.budget.toStringAsFixed(0)}'
                  : '$currencySymbol${row.used.toStringAsFixed(0)} used',
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
    required this.categories,
    required this.currencySymbol,
  });

  final _AnalyticsWidgetKind kind;
  final List<FinanceTransaction> transactions;
  final List<Category> categories;
  final String currencySymbol;

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
        currencySymbol: widget.currencySymbol,
      ),
      _AnalyticsWidgetKind.netEarnings => _MonthlyNetEarningsCard(
        transactions: widget.transactions,
        monthsToShow: _earningMonths,
        currencySymbol: widget.currencySymbol,
      ),
      _AnalyticsWidgetKind.categoryBudgets => _CategoryBudgetCard(
        transactions: widget.transactions,
        categories: widget.categories,
        maxRows: _categoryRows,
        currencySymbol: widget.currencySymbol,
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
        'Average daily expense over $_dailyDays days: ${widget.currencySymbol}${_averageDailyExpense(widget.transactions, _dateOnly(now), _dailyDays).toStringAsFixed(0)}',
        'Current month expense: ${widget.currencySymbol}${monthlyExpense.toStringAsFixed(0)}',
      ],
      _AnalyticsWidgetKind.netEarnings => [
        'Current month income: ${widget.currencySymbol}${monthlyIncome.toStringAsFixed(0)}',
        'Current month expense: ${widget.currencySymbol}${monthlyExpense.toStringAsFixed(0)}',
        'Current month net: ${widget.currencySymbol}${(monthlyIncome - monthlyExpense).toStringAsFixed(0)}',
      ],
      _AnalyticsWidgetKind.categoryBudgets => [
        'Categories with a budget: ${widget.categories.where((c) => c.monthlyLimit != null).length}',
        'Tracked categories: ${widget.categories.length}',
        'Current month expense: ${widget.currencySymbol}${monthlyExpense.toStringAsFixed(0)}',
      ],
      _AnalyticsWidgetKind.spendingCalendar => [
        'Month: ${_monthShortLabel(DateTime(now.year, now.month, 1))} ${now.year}',
        'Current month expense: ${widget.currencySymbol}${monthlyExpense.toStringAsFixed(0)}',
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
