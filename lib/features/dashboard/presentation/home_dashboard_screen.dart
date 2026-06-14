import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/money/money.dart';
import '../../../core/prediction/monte_carlo_engine.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/aiko_data_widgets.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../shared/widgets/screen_states.dart';
import '../../../theme/aiko_colors.dart';
import '../../budgets/domain/budget.dart';
import '../../budgets/presentation/budget_form_screen.dart';
import '../../categories/domain/category.dart';
import '../domain/dashboard_due_item.dart';
import '../domain/dashboard_summary.dart';
import '../domain/dashboard_widget_preference.dart';
import '../../goals/domain/goal.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/transaction_form_screen.dart';
import 'widgets/dashboard_due_items_widget.dart';

class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  ConsumerState<HomeDashboardScreen> createState() =>
      _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen> {
  var _isEditing = false;

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final dueItemsAsync = ref.watch(dashboardDueItemsProvider);
    final layoutAsync = ref.watch(dashboardLayoutProvider);
    final l10n = AppLocalizations.of(context);
    final actionColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.overview),
        actions: [
          IconButton(
            tooltip: l10n.menuTitle,
            onPressed: () => context.push('/settings'),
            icon: Icon(Icons.menu_rounded, color: actionColor),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => context.push('/notifications'),
            icon: Icon(Icons.notifications_none, color: actionColor),
          ),
        ],
      ),
      body: summaryAsync.when(
        loading: () => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
          children: [AikoScreenState.loading()],
        ),
        error: (error, stack) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
          children: [
            AikoScreenState.error(
              title: l10n.dashboardUnavailable,
              message: l10n.dashboardUnavailableMessage,
            ),
          ],
        ),
        data: (summary) => layoutAsync.when(
          loading: () => ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
            children: [AikoScreenState.loading()],
          ),
          error: (_, _) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
            children: [
              ..._layoutChildren(
                context,
                DashboardWidgetPreference.defaultLayout,
                summary,
                dueItemsAsync,
              ),
              const SizedBox(height: 16),
              _DashboardLayoutAction(
                isEditing: _isEditing,
                onPressed: () => setState(() => _isEditing = !_isEditing),
              ),
            ],
          ),
          data: (layout) => _isEditing
              ? _EditableDashboardList(
                  layout: layout,
                  isEditing: _isEditing,
                  onToggleEditing: () =>
                      setState(() => _isEditing = !_isEditing),
                  itemBuilder: (type) =>
                      _buildWidget(context, type, summary, dueItemsAsync),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
                  children: [
                    ..._layoutChildren(context, layout, summary, dueItemsAsync),
                    const SizedBox(height: 16),
                    _DashboardLayoutAction(
                      isEditing: _isEditing,
                      onPressed: () => setState(() => _isEditing = !_isEditing),
                    ),
                  ],
                ),
        ),
      ),
      floatingActionButton: const _QuickAddMenu(),
    );
  }

  List<Widget> _layoutChildren(
    BuildContext context,
    List<DashboardWidgetPreference> layout,
    DashboardSummary summary,
    AsyncValue<List<DashboardDueItem>> dueItemsAsync,
  ) {
    final visible = layout.where((item) => item.isVisible).toList();
    final children = <Widget>[];

    for (var index = 0; index < visible.length; index++) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 16));
      }
      final type = visible[index].type;
      children.add(_buildWidget(context, type, summary, dueItemsAsync));
    }

    return children;
  }

  Widget _buildWidget(
    BuildContext context,
    DashboardWidgetType type,
    DashboardSummary summary,
    AsyncValue<List<DashboardDueItem>> dueItemsAsync,
  ) {
    final l10n = AppLocalizations.of(context);
    return switch (type) {
      DashboardWidgetType.aikoWelcome => FinanceCard(
        title: l10n.hiAiko,
        icon: Icons.auto_awesome,
        accentColor: AikoColors.premiumPurple,
        prominent: true,
        child: Text(l10n.safeToSpendDescription(summary.safeToSpend.format())),
      ),
      DashboardWidgetType.dailySpending => const _DailySpendingPanel(),
      DashboardWidgetType.safeThisWeek => const _SafeThisWeekPanel(),
      DashboardWidgetType.dailySummary => const _OverviewAnalyticsWidget(
        kind: _AnalyticsWidgetKind.dailySummary,
      ),
      DashboardWidgetType.netEarnings => const _OverviewAnalyticsWidget(
        kind: _AnalyticsWidgetKind.netEarnings,
      ),
      DashboardWidgetType.categoryBudgets => const _OverviewAnalyticsWidget(
        kind: _AnalyticsWidgetKind.categoryBudgets,
      ),
      DashboardWidgetType.spendingCalendar => const _OverviewAnalyticsWidget(
        kind: _AnalyticsWidgetKind.spendingCalendar,
      ),
      DashboardWidgetType.dueItems => dueItemsAsync.when(
        loading: () => FinanceCard(
          title: l10n.upcomingDueDates,
          icon: Icons.event_available_outlined,
          child: const Text('Loading upcoming due dates…'),
        ),
        error: (error, stack) => FinanceCard(
          title: l10n.upcomingDueDates,
          icon: Icons.event_available_outlined,
          child: Text(l10n.unableToLoadDueDates),
        ),
        data: (items) => DashboardDueItemsWidget(items: items),
      ),
      DashboardWidgetType.thisMonthOverview => _ThisMonthOverviewSection(
        summary: summary,
      ),
      DashboardWidgetType.cashFlowMapping => const _CashFlowMappingPanel(),
      DashboardWidgetType.aikoGoalSimulator => const _AikoGoalSimulatorPanel(),
      DashboardWidgetType.totalBalance => const _TotalBalancePanel(),
      DashboardWidgetType.leftToSave => const _LeftToSavePanel(),
      DashboardWidgetType.cashFlow => const _CashFlowPanel(),
      DashboardWidgetType.netWorth => const _NetWorthPanel(),
      DashboardWidgetType.netWorthTrend => const _NetWorthTrendPanel(),
      DashboardWidgetType.assetsLiabilities => const _AssetsLiabilitiesPanel(),
      DashboardWidgetType.topAssets => const _TopAssetsPanel(),
      DashboardWidgetType.totalDebt => const _TotalDebtPanel(),
      DashboardWidgetType.debtBreakdown => const _DebtBreakdownPanel(),
      DashboardWidgetType.taxLiability => const _TaxLiabilityPanel(),
      DashboardWidgetType.taxBreakdown => const _TaxBreakdownPanel(),
      DashboardWidgetType.topDeductions => const _TopDeductionsPanel(),
    };
  }
}

class _EditableDashboardList extends ConsumerWidget {
  const _EditableDashboardList({
    required this.layout,
    required this.isEditing,
    required this.onToggleEditing,
    required this.itemBuilder,
  });

  final List<DashboardWidgetPreference> layout;
  final bool isEditing;
  final VoidCallback onToggleEditing;
  final Widget Function(DashboardWidgetType type) itemBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = layout.where((item) => item.isVisible).toList();
    final hidden = layout.where((item) => !item.isVisible).toList();
    final notifier = ref.read(dashboardLayoutProvider.notifier);

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
      itemCount: visible.length + 2,
      onReorderItem: notifier.reorderItem,
      buildDefaultDragHandles: false,
      itemBuilder: (context, index) {
        if (index == visible.length) {
          return _AddWidgetsPanel(
            key: const ValueKey('dashboard-add-widgets'),
            hidden: hidden,
          );
        }
        if (index == visible.length + 1) {
          return Padding(
            key: const ValueKey('dashboard-edit-layout-action'),
            padding: const EdgeInsets.only(bottom: 16),
            child: _DashboardLayoutAction(
              isEditing: isEditing,
              onPressed: onToggleEditing,
            ),
          );
        }
        final item = visible[index];
        return Padding(
          key: ValueKey(item.type),
          padding: const EdgeInsets.only(bottom: 16),
          child: Stack(
            children: [
              AnimatedScale(
                scale: 0.99,
                duration: const Duration(milliseconds: 150),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: AikoColors.primaryBlue),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: itemBuilder(item.type),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'Remove ${item.type.label}',
                      onPressed: () => notifier.removeWidget(item.type),
                      icon: const Icon(Icons.delete_outline),
                    ),
                    const SizedBox(width: 8),
                    ReorderableDragStartListener(
                      index: index,
                      child: const IconButton.filledTonal(
                        tooltip: 'Drag to reorder',
                        onPressed: null,
                        icon: Icon(Icons.drag_handle),
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

class _ThisMonthOverviewSection extends StatelessWidget {
  const _ThisMonthOverviewSection({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final netCashFlow = summary.monthlyIncome - summary.monthlySpending;

    return AikoDataListCard(
      title: 'This Month Overview',
      icon: Icons.calendar_month_outlined,
      rows: [
        AikoDataRow(
          label: 'Income',
          value: summary.monthlyIncome.format(),
          color: AikoColors.successGreen,
        ),
        AikoDataRow(
          label: 'Expenses',
          value: '-${summary.monthlySpending.format()}',
          color: AikoColors.dangerRed,
        ),
        AikoDataRow(
          label: 'Savings',
          value: netCashFlow.format(),
          color: AikoColors.analyticsTeal,
        ),
      ],
    );
  }
}

class _TotalDebtPanel extends StatelessWidget {
  const _TotalDebtPanel();

  @override
  Widget build(BuildContext context) {
    return const AikoMetricCard(
      label: 'Total Debt',
      value: '\$47,250.00',
      change: '-\$1,250 vs last month',
      icon: Icons.account_balance_wallet_outlined,
      accentColor: AikoColors.dangerRed,
      progress: 0.32,
    );
  }
}

class _DebtBreakdownPanel extends StatelessWidget {
  const _DebtBreakdownPanel();

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return AikoDataListCard(
      title: 'Debt Breakdown',
      icon: Icons.pie_chart_outline,
      rows: [
        AikoDataRow(
          label: 'Credit Cards',
          value: '\$6,250.00',
          color: AikoColors.warningOrange,
        ),
        AikoDataRow(
          label: 'Student Loans',
          value: '\$28,500.00',
          color: AikoColors.primaryBlue,
        ),
        AikoDataRow(
          label: 'Personal Loans',
          value: '\$7,500.00',
          color: AikoColors.premiumPurple,
        ),
        AikoDataRow(label: 'Other Debt', value: '\$5,000.00', color: muted),
      ],
    );
  }
}

class _TaxLiabilityPanel extends StatelessWidget {
  const _TaxLiabilityPanel();

  @override
  Widget build(BuildContext context) {
    return const AikoMetricCard(
      label: 'Estimated Tax Liability',
      value: r'$8,750.00',
      change: r'-$520 vs 2025',
      icon: Icons.request_quote_outlined,
      accentColor: AikoColors.successGreen,
    );
  }
}

class _TaxBreakdownPanel extends StatelessWidget {
  const _TaxBreakdownPanel();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: AikoDonutChart(
          values: [6250.0, 1500.0, 600.0, 400.0],
          colors: [
            AikoColors.primaryBlue,
            AikoColors.dangerRed,
            AikoColors.analyticsTeal,
            AikoColors.warningOrange,
          ],
          centerLabel:
              r'$8,750'
              '\nTax',
        ),
      ),
    );
  }
}

class _TopDeductionsPanel extends StatelessWidget {
  const _TopDeductionsPanel();

  @override
  Widget build(BuildContext context) {
    return const AikoDataListCard(
      title: 'Top Deductions',
      icon: Icons.fact_check_outlined,
      rows: [
        AikoDataRow(label: 'Mortgage Interest', value: r'$3,650.00'),
        AikoDataRow(label: 'Charitable Donations', value: r'$2,020.00'),
        AikoDataRow(label: 'Medical Expenses', value: r'$1,450.00'),
        AikoDataRow(label: 'Business Expenses', value: r'$1,230.00'),
      ],
    );
  }
}

class _TotalBalancePanel extends ConsumerWidget {
  const _TotalBalancePanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    return summaryAsync.when(
      loading: () => const _OverviewMiniCard(
        title: 'Total balance',
        value: 'Loading',
        caption: 'Cash',
        icon: Icons.account_balance_wallet_outlined,
        accentColor: AikoColors.successGreen,
      ),
      error: (_, _) => const _OverviewMiniCard(
        title: 'Total balance',
        value: 'Unavailable',
        caption: 'Cash',
        icon: Icons.account_balance_wallet_outlined,
        accentColor: AikoColors.successGreen,
      ),
      data: (summary) {
        final progress = _moneyRatio(summary.totalCash, summary.netWorth);
        return _OverviewMiniCard(
          title: 'Total balance',
          value: summary.netWorth.format(),
          caption: 'Cash ${summary.totalCash.format()}',
          icon: Icons.account_balance_wallet_outlined,
          accentColor: AikoColors.successGreen,
          progressValue: progress,
        );
      },
    );
  }

  double _moneyRatio(Money value, Money target) {
    if (target.amount == Money.zero(target.currency).amount ||
        value.currency != target.currency) {
      return 0;
    }
    return (value.amount.toDouble() / target.amount.toDouble()).clamp(0.0, 1.0);
  }
}

class _LeftToSavePanel extends ConsumerWidget {
  const _LeftToSavePanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    return summaryAsync.when(
      loading: () => const _OverviewMiniCard(
        title: 'Left to save',
        value: 'Loading',
        caption: 'After safe spending',
        icon: Icons.flag_outlined,
        accentColor: AikoColors.analyticsTeal,
      ),
      error: (_, _) => const _OverviewMiniCard(
        title: 'Left to save',
        value: 'Unavailable',
        caption: 'After safe spending',
        icon: Icons.flag_outlined,
        accentColor: AikoColors.analyticsTeal,
      ),
      data: (summary) {
        final netCashFlow = summary.monthlyIncome - summary.monthlySpending;
        final leftToSave = netCashFlow - summary.safeToSpend;
        return _OverviewMiniCard(
          title: 'Left to save',
          value: leftToSave.format(),
          caption: 'After safe spending',
          icon: Icons.flag_outlined,
          accentColor: AikoColors.analyticsTeal,
        );
      },
    );
  }
}

class _CashFlowPanel extends ConsumerWidget {
  const _CashFlowPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    return summaryAsync.when(
      loading: () => const _OverviewMiniCard(
        title: 'Cash flow',
        value: 'Loading',
        caption: 'Income minus expenses',
        icon: Icons.waterfall_chart,
        accentColor: AikoColors.successGreen,
      ),
      error: (_, _) => const _OverviewMiniCard(
        title: 'Cash flow',
        value: 'Unavailable',
        caption: 'Income minus expenses',
        icon: Icons.waterfall_chart,
        accentColor: AikoColors.successGreen,
      ),
      data: (summary) {
        final netCashFlow = summary.monthlyIncome - summary.monthlySpending;
        return _OverviewMiniCard(
          title: 'Cash flow',
          value: netCashFlow.format(),
          caption: 'Income minus expenses',
          icon: Icons.waterfall_chart,
          accentColor: netCashFlow.isNegative
              ? AikoColors.dangerRed
              : AikoColors.successGreen,
        );
      },
    );
  }
}

class _NetWorthPanel extends ConsumerWidget {
  const _NetWorthPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    return summaryAsync.when(
      loading: () => const _OverviewMiniCard(
        title: 'Net worth',
        value: 'Loading',
        caption: 'Assets minus liabilities',
        icon: Icons.account_balance_wallet_outlined,
        accentColor: AikoColors.successGreen,
      ),
      error: (_, _) => const _OverviewMiniCard(
        title: 'Net worth',
        value: 'Unavailable',
        caption: 'Assets minus liabilities',
        icon: Icons.account_balance_wallet_outlined,
        accentColor: AikoColors.successGreen,
      ),
      data: (summary) {
        return _OverviewMiniCard(
          title: 'Net worth',
          value: summary.netWorth.format(),
          caption: 'Assets minus liabilities',
          icon: Icons.account_balance_wallet_outlined,
          accentColor: AikoColors.successGreen,
        );
      },
    );
  }
}

class _NetWorthTrendPanel extends StatelessWidget {
  const _NetWorthTrendPanel();

  @override
  Widget build(BuildContext context) {
    return FinanceCard(
      title: 'Net worth trend',
      icon: Icons.trending_up_outlined,
      accentColor: AikoColors.primaryBlue,
      child: SizedBox(
        height: 120,
        child: BarChart(
          BarChartData(
            barGroups: _generateTrendData(),
            titlesData: const FlTitlesData(show: false),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(enabled: false),
          ),
        ),
      ),
    );
  }

  List<BarChartGroupData> _generateTrendData() {
    final values = [80, 82, 84, 90, 88, 95, 100, 106, 111, 118, 126, 148];
    return List.generate(values.length, (index) {
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: values[index].toDouble(),
            color: AikoColors.primaryBlue,
            width: 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    });
  }
}

class _AssetsLiabilitiesPanel extends ConsumerWidget {
  const _AssetsLiabilitiesPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    return summaryAsync.when(
      loading: () => const FinanceCard(
        title: 'Assets & liabilities',
        icon: Icons.balance_outlined,
        accentColor: AikoColors.analyticsTeal,
        child: Text('Loading...'),
      ),
      error: (_, _) => const FinanceCard(
        title: 'Assets & liabilities',
        icon: Icons.balance_outlined,
        accentColor: AikoColors.analyticsTeal,
        child: Text('Unavailable'),
      ),
      data: (summary) {
        final assets = summary.netWorth + summary.totalCash;
        final liabilities = summary.totalCash;
        return FinanceCard(
          title: 'Assets & liabilities',
          icon: Icons.balance_outlined,
          accentColor: AikoColors.analyticsTeal,
          child: Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Assets',
                  value: assets.format(),
                  icon: Icons.add_chart,
                  color: AikoColors.successGreen,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _MetricTile(
                  label: 'Liabilities',
                  value: liabilities.format(),
                  icon: Icons.remove_circle_outline,
                  color: AikoColors.dangerRed,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _TopAssetsPanel extends ConsumerWidget {
  const _TopAssetsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    return summaryAsync.when(
      loading: () => const FinanceCard(
        title: 'Top assets',
        icon: Icons.inventory_2_outlined,
        accentColor: AikoColors.analyticsTeal,
        child: Text('Loading...'),
      ),
      error: (_, _) => const FinanceCard(
        title: 'Top assets',
        icon: Icons.inventory_2_outlined,
        accentColor: AikoColors.analyticsTeal,
        child: Text('Unavailable'),
      ),
      data: (summary) {
        return FinanceCard(
          title: 'Top assets',
          icon: Icons.inventory_2_outlined,
          accentColor: AikoColors.analyticsTeal,
          child: Column(
            children: [
              _AssetRow(
                label: 'Cash & Bank',
                value: summary.totalCash.format(),
                color: AikoColors.primaryBlue,
              ),
              const SizedBox(height: 12),
              _AssetRow(
                label: 'Net worth',
                value: summary.netWorth.format(),
                color: AikoColors.successGreen,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AssetRow extends StatelessWidget {
  const _AssetRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _DashboardLayoutAction extends StatelessWidget {
  const _DashboardLayoutAction({
    required this.isEditing,
    required this.onPressed,
  });

  final bool isEditing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final actionColor = Theme.of(context).colorScheme.primary;

    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: actionColor,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(isEditing ? Icons.check : Icons.edit_outlined),
      label: Text(isEditing ? 'Done' : 'Edit layout'),
    );
  }
}

class _AddWidgetsPanel extends ConsumerWidget {
  const _AddWidgetsPanel({super.key, required this.hidden});

  final List<DashboardWidgetPreference> hidden;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(dashboardLayoutProvider.notifier);
    return FinanceCard(
      title: 'Add widgets',
      icon: Icons.add_chart_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hidden.isEmpty)
            Text(
              'All overview widgets are visible.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            for (final item in hidden)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.type.label),
                trailing: IconButton(
                  tooltip: 'Add ${item.type.label}',
                  onPressed: () => notifier.addWidget(item.type),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: notifier.resetToDefault,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset to default'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailySpendingPanel extends ConsumerWidget {
  const _DailySpendingPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsProvider);
    final transactionsAsync = ref.watch(transactionsProvider);

    return budgetsAsync.when(
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
        if (dailyBudget == null) {
          return const _OverviewMiniCard(
            title: 'Daily spending',
            value: 'Set up Daily Spending to track today\'s limit',
            caption: '',
            icon: Icons.today_outlined,
            accentColor: AikoColors.warningOrange,
            valueMaxLines: 2,
          );
        }

        return transactionsAsync.when(
          loading: () => const _OverviewMiniCard(
            title: 'Daily spending',
            value: 'Loading',
            caption: 'Current / limit',
            icon: Icons.today_outlined,
            accentColor: AikoColors.warningOrange,
          ),
          error: (_, _) => const _OverviewMiniCard(
            title: 'Daily spending',
            value: 'Unavailable',
            caption: 'Current / limit',
            icon: Icons.today_outlined,
            accentColor: AikoColors.warningOrange,
          ),
          data: (transactions) {
            final current = _dailySpendingUsed(
              budget: dailyBudget!,
              transactions: transactions,
            );
            final progress = _budgetProgressValue(
              used: current,
              limit: dailyBudget.amount,
            );

            return _OverviewMiniCard(
              title: 'Daily spending',
              value: '${current.format()} / ${dailyBudget.amount.format()}',
              caption: 'Current / limit',
              icon: Icons.today_outlined,
              accentColor: AikoColors.warningOrange,
              progressValue: progress,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BudgetFormScreen(initialBudget: dailyBudget),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Money _dailySpendingUsed({
    required Budget budget,
    required List<FinanceTransaction> transactions,
  }) {
    final today = DateTime.now();
    var used = Money.zero(budget.amount.currency);

    for (final transaction in transactions) {
      final isToday =
          transaction.date.year == today.year &&
          transaction.date.month == today.month &&
          transaction.date.day == today.day;
      if (!isToday ||
          !transaction.isExpense ||
          transaction.status != TransactionStatus.posted ||
          !budget.includesCategory(transaction.categoryId) ||
          transaction.amount.currency != budget.amount.currency) {
        continue;
      }
      used = used + transaction.amount;
    }

    return used;
  }

  double _budgetProgressValue({required Money used, required Money limit}) {
    if (limit.amount == Money.zero(limit.currency).amount) {
      return 0;
    }
    return (used.amount.toDouble() / limit.amount.toDouble()).clamp(0.0, 1.0);
  }
}

class _SafeThisWeekPanel extends ConsumerWidget {
  const _SafeThisWeekPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);

    return summaryAsync.when(
      loading: () => const _OverviewMiniCard(
        title: 'Safe this week',
        value: 'Loading',
        caption: 'Estimate',
        icon: Icons.savings_outlined,
        accentColor: AikoColors.analyticsTeal,
      ),
      error: (_, _) => const _OverviewMiniCard(
        title: 'Safe this week',
        value: 'Unavailable',
        caption: 'Estimate',
        icon: Icons.savings_outlined,
        accentColor: AikoColors.analyticsTeal,
      ),
      data: (summary) => _OverviewMiniCard(
        title: 'Safe this week',
        value: summary.safeToSpend.format(),
        caption: 'Estimate',
        icon: Icons.savings_outlined,
        accentColor: AikoColors.analyticsTeal,
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
    this.progressValue,
    this.valueMaxLines = 1,
  });

  final String title;
  final String value;
  final String caption;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;
  final double? progressValue;
  final int valueMaxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(8);
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
            maxLines: valueMaxLines,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: accentColor,
            ),
          ),
          if (progressValue != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progressValue,
                minHeight: 8,
                color: accentColor,
                backgroundColor: accentColor.withValues(alpha: 0.16),
              ),
            ),
          ],
          const SizedBox(height: 4),
          if (caption.isNotEmpty)
            Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, borderRadius: radius, child: content),
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

        final currencyFormat = NumberFormat.simpleCurrency(name: 'USD');

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

class _AikoGoalSimulatorPanel extends ConsumerWidget {
  const _AikoGoalSimulatorPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);

    return goalsAsync.when(
      loading: () => const FinanceCard(
        title: 'Aiko Goal Simulator',
        icon: Icons.query_stats_outlined,
        accentColor: AikoColors.premiumPurple,
        child: Text('Loading goal simulation...'),
      ),
      error: (_, _) => const FinanceCard(
        title: 'Aiko Goal Simulator',
        icon: Icons.query_stats_outlined,
        accentColor: AikoColors.premiumPurple,
        child: Text('Unable to load goal simulation right now.'),
      ),
      data: (goals) {
        final activeGoals = goals
            .where((goal) => goal.status == GoalStatus.active)
            .toList();
        if (activeGoals.isEmpty) {
          return const _MockGoalSimulationCard();
        }

        return Column(
          children: [
            for (final goal in activeGoals) ...[
              _GoalMonteCarloCard(goal: goal),
              const SizedBox(height: 16),
            ],
          ],
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

class _GoalMonteCarloCard extends StatelessWidget {
  const _GoalMonteCarloCard({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();
    var months =
        ((goal.targetDate.year - now.year) * 12) +
        goal.targetDate.month -
        now.month;
    if (months <= 0) months = 1;

    final targetNeeded = goal.remaining.amount.toDouble();
    var monthlyContribution = targetNeeded / months;
    if (monthlyContribution <= 0) monthlyContribution = 100.0;

    const engine = MonteCarloEngine();
    final result = engine.run(
      currentBalance: goal.currentAmount.amount.toDouble(),
      monthlyContribution: monthlyContribution,
      targetAmount: goal.targetAmount.amount.toDouble(),
      targetMonths: months,
      expectedAnnualReturnPercent: 6.0,
      annualVolatilityPercent: 12.0,
    );
    final currencyFormat = NumberFormat.simpleCurrency(name: 'USD');

    return FinanceCard(
      title: 'Monte Carlo: ${goal.name}',
      icon: Icons.auto_awesome,
      accentColor: AikoColors.premiumPurple,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _GoalProbabilityHeader(probability: result.successProbabilityPercent),
          const SizedBox(height: 16),
          Text(
            'Based on 1,000 simulations at 6% expected return and 12% volatility with monthly savings of ${currencyFormat.format(monthlyContribution)}.',
            style: textTheme.bodySmall,
          ),
          const Divider(height: 24),
          Text(
            'Projected future balance bands in $months months:',
            style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _ProjectionBands(
            conservative: currencyFormat.format(result.conservativeValue),
            expected: currencyFormat.format(result.expectedValue),
            optimistic: currencyFormat.format(result.optimisticValue),
          ),
        ],
      ),
    );
  }
}

class _MockGoalSimulationCard extends StatelessWidget {
  const _MockGoalSimulationCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final currencyFormat = NumberFormat.simpleCurrency(name: 'USD');

    return FinanceCard(
      title: 'Aiko Goal Simulator',
      icon: Icons.query_stats_outlined,
      accentColor: AikoColors.premiumPurple,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _GoalProbabilityHeader(probability: 94.2),
          const SizedBox(height: 16),
          Text(
            'Set up a SMART savings goal to run real-time Monte Carlo models forecasting your actual chance of success under volatile market bands.',
            style: textTheme.bodyMedium,
          ),
          const Divider(height: 24),
          Text(
            'Simulated Future Emergency Fund Bands (18 Months):',
            style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _ProjectionBands(
            conservative: currencyFormat.format(4250.0),
            expected: currencyFormat.format(4720.0),
            optimistic: currencyFormat.format(5380.0),
          ),
        ],
      ),
    );
  }
}

class _GoalProbabilityHeader extends StatelessWidget {
  const _GoalProbabilityHeader({required this.probability});

  final double probability;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = _probabilityColor(probability);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Goal Completion Chance', style: textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                '${probability.toStringAsFixed(1)}%',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        CircularProgressIndicator(
          value: probability / 100,
          color: color,
          backgroundColor: Colors.grey.withValues(alpha: 0.2),
        ),
      ],
    );
  }
}

class _ProjectionBands extends StatelessWidget {
  const _ProjectionBands({
    required this.conservative,
    required this.expected,
    required this.optimistic,
  });

  final String conservative;
  final String expected;
  final String optimistic;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _BandColumn(
          label: 'Conservative',
          amount: conservative,
          color: Colors.grey,
          textTheme: textTheme,
        ),
        _BandColumn(
          label: 'Expected',
          amount: expected,
          color: AikoColors.deepBlue,
          textTheme: textTheme,
        ),
        _BandColumn(
          label: 'Optimistic',
          amount: optimistic,
          color: AikoColors.successGreen,
          textTheme: textTheme,
        ),
      ],
    );
  }
}

class _BandColumn extends StatelessWidget {
  const _BandColumn({
    required this.label,
    required this.amount,
    required this.color,
    required this.textTheme,
  });

  final String label;
  final String amount;
  final Color color;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
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

Color _probabilityColor(double probability) {
  if (probability >= 80) return AikoColors.successGreen;
  if (probability >= 50) return AikoColors.warningOrange;
  return AikoColors.dangerRed;
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
    final budgetsAsync = ref.watch(budgetsProvider);
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
        final budgets =
            budgetsAsync.whenOrNull(data: (items) => items) ?? const <Budget>[];
        final categories =
            categoriesAsync.whenOrNull(data: (items) => items) ??
            const <Category>[];

        return switch (kind) {
          _AnalyticsWidgetKind.dailySummary => _DailySummaryCard(
            transactions: transactions,
            onTap: () => _openAnalyticsDetail(
              context,
              kind: kind,
              transactions: transactions,
              budgets: budgets,
              categories: categories,
            ),
          ),
          _AnalyticsWidgetKind.netEarnings => _MonthlyNetEarningsCard(
            transactions: transactions,
            onTap: () => _openAnalyticsDetail(
              context,
              kind: kind,
              transactions: transactions,
              budgets: budgets,
              categories: categories,
            ),
          ),
          _AnalyticsWidgetKind.categoryBudgets => _CategoryBudgetCard(
            transactions: transactions,
            budgets: budgets,
            categories: categories,
            onTap: () => _openAnalyticsDetail(
              context,
              kind: kind,
              transactions: transactions,
              budgets: budgets,
              categories: categories,
            ),
          ),
          _AnalyticsWidgetKind.spendingCalendar => _SpendingCalendarCard(
            transactions: transactions,
            onTap: () => _openAnalyticsDetail(
              context,
              kind: kind,
              transactions: transactions,
              budgets: budgets,
              categories: categories,
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
