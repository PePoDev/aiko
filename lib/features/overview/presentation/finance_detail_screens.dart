import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/money/money.dart';
import '../../../shared/widgets/aiko_data_widgets.dart';
import '../../../shared/widgets/screen_states.dart';
import '../../../theme/aiko_colors.dart';
import '../../accounts/domain/account.dart';
import '../../categories/domain/category.dart';
import '../../categories/presentation/category_visual.dart';
import '../../dashboard/domain/app_notification.dart';
import '../../investments/application/investments_provider.dart';
import '../../investments/domain/investment_holding.dart';
import '../domain/monthly_report.dart';

class NotificationsCenterScreen extends ConsumerWidget {
  const NotificationsCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return AikoDetailScaffold(
      title: 'Notifications',
      children: [
        notificationsAsync.when(
          loading: () => const AikoScreenState.loading(),
          error: (_, _) => const AikoScreenState.error(
            title: 'Notifications unavailable',
            message: 'Aiko could not read your data right now. Pull to retry.',
          ),
          data: (notifications) {
            if (notifications.isEmpty) {
              return const AikoScreenState.empty(
                title: 'All caught up',
                message:
                    'No budget alerts, upcoming bills, or goal milestones right now.',
              );
            }
            return Column(
              children: [
                for (final group in AppNotificationGroup.values)
                  if (notifications.any((n) => n.group == group))
                    _NotificationGroupCard(
                      group: group,
                      notifications: notifications
                          .where((n) => n.group == group)
                          .toList(growable: false),
                    ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _NotificationGroupCard extends StatelessWidget {
  const _NotificationGroupCard({
    required this.group,
    required this.notifications,
  });

  final AppNotificationGroup group;
  final List<AppNotification> notifications;

  @override
  Widget build(BuildContext context) {
    return AikoDataListCard(
      title: _groupTitle(group),
      icon: _groupIcon(group),
      rows: [
        for (final n in notifications)
          AikoDataRow(
            label: n.title,
            subtitle: n.subtitle,
            value: '',
            color: _severityColor(n.severity),
            icon: _severityIcon(n.severity),
          ),
      ],
    );
  }
}

String _groupTitle(AppNotificationGroup group) => switch (group) {
  AppNotificationGroup.budget => 'Budget alerts',
  AppNotificationGroup.bills => 'Upcoming bills',
  AppNotificationGroup.goals => 'Goals',
};

IconData _groupIcon(AppNotificationGroup group) => switch (group) {
  AppNotificationGroup.budget => Icons.pie_chart_outline,
  AppNotificationGroup.bills => Icons.receipt_long_outlined,
  AppNotificationGroup.goals => Icons.flag_outlined,
};

Color _severityColor(AppNotificationSeverity severity) => switch (severity) {
  AppNotificationSeverity.info => AikoColors.primaryBlue,
  AppNotificationSeverity.success => AikoColors.successGreen,
  AppNotificationSeverity.warning => AikoColors.warningOrange,
  AppNotificationSeverity.danger => AikoColors.dangerRed,
};

IconData _severityIcon(AppNotificationSeverity severity) => switch (severity) {
  AppNotificationSeverity.info => Icons.info_outline,
  AppNotificationSeverity.success => Icons.check_circle_outline,
  AppNotificationSeverity.warning => Icons.warning_amber_outlined,
  AppNotificationSeverity.danger => Icons.error_outline,
};

/// Returns a semantic color for how a fraction of budget used compares to how
/// far through the month we are. Over budget = red, ahead of the calendar =
/// orange, otherwise green.
Color _paceColor(double fraction, double daysElapsedRatio) {
  if (fraction > 1) return AikoColors.dangerRed;
  if (fraction > daysElapsedRatio) return AikoColors.warningOrange;
  return AikoColors.successGreen;
}

class PaceOverviewScreen extends ConsumerWidget {
  const PaceOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paceAsync = ref.watch(budgetPaceProvider);
    return AikoDetailScaffold(
      title: 'Pace Overview',
      children: [
        paceAsync.when(
          loading: () => const AikoScreenState.loading(),
          error: (_, _) => const AikoScreenState.error(
            title: 'Pace unavailable',
            message: 'Aiko could not read your budgets right now.',
          ),
          data: (pace) {
            if (!pace.hasBudgets) {
              return const AikoScreenState.empty(
                title: 'No budgets yet',
                message:
                    'Add a budget limit to a category and Aiko will track your '
                    'pace against it here.',
              );
            }
            final overall = pace.fraction;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AikoInlineNotice(
                  title: pace.isAheadOfPace
                      ? 'Spending ahead of pace'
                      : 'You are on track',
                  message: pace.isAheadOfPace
                      ? 'You have used ${(overall * 100).round()}% of budget '
                            '${(pace.daysElapsedRatio * 100).round()}% into the '
                            'month.'
                      : '${pace.totalSpent.format()} of ${pace.totalBudget.format()} '
                            'spent so far this month.',
                  icon: Icons.speed_outlined,
                  accentColor: pace.isAheadOfPace
                      ? AikoColors.warningOrange
                      : AikoColors.successGreen,
                ),
                AikoMetricCard(
                  label: 'Overall Pace',
                  value: '${(overall * 100).round()}%',
                  change:
                      '${pace.totalSpent.format()} of ${pace.totalBudget.format()}',
                  icon: Icons.route_outlined,
                  accentColor: _paceColor(overall, pace.daysElapsedRatio),
                  progress: overall.clamp(0.0, 1.0),
                ),
                AikoDataListCard(
                  title: 'Category Pace',
                  icon: Icons.category_outlined,
                  rows: [
                    for (final c in pace.categories)
                      AikoDataRow(
                        label: c.name,
                        value: '${(c.fraction * 100).round()}%',
                        subtitle: '${c.spent.format()} of ${c.limit.format()}',
                        color: _paceColor(c.fraction, pace.daysElapsedRatio),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class SafeToSpendScreen extends ConsumerWidget {
  const SafeToSpendScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final safeAsync = ref.watch(safeToSpendProvider);
    return AikoDetailScaffold(
      title: 'Safe to Spend',
      children: [
        safeAsync.when(
          loading: () => const AikoScreenState.loading(),
          error: (_, _) => const AikoScreenState.error(
            title: 'Unavailable',
            message: 'Aiko could not read your income and budgets right now.',
          ),
          data: (safe) {
            final leftoverColor = safe.leftover.isNegative
                ? AikoColors.dangerRed
                : AikoColors.successGreen;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AikoMetricCard(
                  label: 'Safe to Spend',
                  value: safe.leftover.format(),
                  change: 'Leftover for ${safe.daysRemaining} days',
                  icon: Icons.savings_outlined,
                  accentColor: leftoverColor,
                ),
                AikoDataListCard(
                  title: 'Breakdown',
                  icon: Icons.list_alt_outlined,
                  rows: [
                    AikoDataRow(
                      label: 'Income',
                      value: safe.income.format(),
                      color: AikoColors.successGreen,
                    ),
                    AikoDataRow(
                      label: 'Spent so far',
                      value: '-${safe.spent.format()}',
                      color: AikoColors.dangerRed,
                    ),
                    AikoDataRow(
                      label: 'Budgeted (unspent)',
                      value: '-${safe.reserved.format()}',
                      color: AikoColors.warningOrange,
                    ),
                    AikoDataRow(
                      label: 'Leftover',
                      value: safe.leftover.format(),
                      color: leftoverColor,
                    ),
                  ],
                ),
                AikoMetricCard(
                  label: 'Daily Safe to Spend',
                  value: safe.perDay.format(),
                  change: 'Average for the rest of the month',
                  icon: Icons.today_outlined,
                  accentColor: leftoverColor,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class CashFlowOverviewScreen extends ConsumerWidget {
  const CashFlowOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flowAsync = ref.watch(cashFlowOverviewProvider);
    return AikoDetailScaffold(
      title: 'Cash Flow',
      children: [
        flowAsync.when(
          loading: () => const AikoScreenState.loading(),
          error: (_, _) => const AikoScreenState.error(
            title: 'Cash flow unavailable',
            message: 'Aiko could not read your transactions right now.',
          ),
          data: (flow) {
            if (!flow.hasActivity) {
              return const AikoScreenState.empty(
                title: 'Nothing logged yet',
                message:
                    'Log income and expenses and your cash flow will appear '
                    'here.',
              );
            }
            final netColor = flow.net.isNegative
                ? AikoColors.dangerRed
                : AikoColors.successGreen;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AikoMetricCard(
                  label: 'Net Cash Flow',
                  value: flow.net.format(),
                  change: 'This month',
                  icon: Icons.waterfall_chart,
                  accentColor: netColor,
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: AikoMiniBarChart(
                      // Net can dip below zero; the chart shows the trend
                      // shape, the summary rows carry exact signed figures.
                      values: flow.monthlyNet
                          .map((v) => v < 0 ? 0.0 : v)
                          .toList(),
                      color: netColor,
                    ),
                  ),
                ),
                AikoDataListCard(
                  title: 'This Month',
                  icon: Icons.account_tree_outlined,
                  rows: [
                    AikoDataRow(
                      label: 'Income',
                      value: flow.income.format(),
                      color: AikoColors.successGreen,
                    ),
                    AikoDataRow(
                      label: 'Expenses',
                      value: '-${flow.expenses.format()}',
                      color: AikoColors.dangerRed,
                    ),
                    AikoDataRow(
                      label: 'Net Cash Flow',
                      value: flow.net.format(),
                      color: netColor,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

String _groupLabel(CategoryBudgetGroup group) => switch (group) {
  CategoryBudgetGroup.needs => 'Needs',
  CategoryBudgetGroup.wants => 'Wants',
  CategoryBudgetGroup.savings => 'Savings',
  CategoryBudgetGroup.debt => 'Debt',
  CategoryBudgetGroup.investment => 'Investments',
  CategoryBudgetGroup.tax => 'Tax',
  CategoryBudgetGroup.business => 'Business',
  CategoryBudgetGroup.custom => 'Other',
};

Color _groupColor(CategoryBudgetGroup group) => switch (group) {
  CategoryBudgetGroup.needs => AikoColors.primaryBlue,
  CategoryBudgetGroup.wants => AikoColors.warningOrange,
  CategoryBudgetGroup.savings => AikoColors.analyticsTeal,
  CategoryBudgetGroup.debt => AikoColors.dangerRed,
  CategoryBudgetGroup.investment => AikoColors.premiumPurple,
  CategoryBudgetGroup.tax => AikoColors.deepBlue,
  CategoryBudgetGroup.business => AikoColors.successGreen,
  // Neutral grey for the "Other" data-viz slice (matches the report donut).
  CategoryBudgetGroup.custom => const Color(0xFF778196),
};

class CashFlowSankeyScreen extends ConsumerWidget {
  const CashFlowSankeyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sankeyAsync = ref.watch(cashFlowSankeyProvider);
    return AikoDetailScaffold(
      title: 'Cash Flow Sankey',
      children: [
        sankeyAsync.when(
          loading: () => const AikoScreenState.loading(),
          error: (_, _) => const AikoScreenState.error(
            title: 'Unavailable',
            message: 'Aiko could not read your transactions right now.',
          ),
          data: (sankey) {
            if (!sankey.hasActivity) {
              return const AikoScreenState.empty(
                title: 'Nothing to map yet',
                message:
                    'Log income and spending and Aiko will map where your '
                    'money flows.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Illustrative flow diagram; the legend below carries the real
                // per-group figures.
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: AikoSankeyPreview(),
                  ),
                ),
                AikoDataListCard(
                  title: 'Flow Legend',
                  rows: [
                    AikoDataRow(
                      label: 'Income',
                      value: sankey.income.format(),
                      color: AikoColors.successGreen,
                    ),
                    for (final slice in sankey.outflowByGroup)
                      AikoDataRow(
                        label: _groupLabel(slice.group),
                        value: '-${slice.amount.format()}',
                        color: _groupColor(slice.group),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Highest-priority goal (high > medium > low), tie-broken by the nearest
/// target date, used when the screen is opened without a specific goal.
Account? _topGoal(List<Account> accounts) {
  final goals = accounts.where((a) => a.type == AccountType.goal).toList();
  if (goals.isEmpty) return null;
  goals.sort((a, b) {
    final byPriority = a.priority.index.compareTo(b.priority.index);
    if (byPriority != 0) return byPriority;
    final aDate = a.targetDate ?? DateTime(9999);
    final bDate = b.targetDate ?? DateTime(9999);
    return aDate.compareTo(bDate);
  });
  return goals.first;
}

class ChanceOfSuccessScreen extends ConsumerWidget {
  const ChanceOfSuccessScreen({this.goal, super.key});

  /// Optional specific goal (passed via route `extra`). When null the screen
  /// shows the top-priority goal.
  final Account? goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);
    return AikoDetailScaffold(
      title: 'Chance of Success',
      children: [
        accountsAsync.when(
          loading: () => const AikoScreenState.loading(),
          error: (_, _) => const AikoScreenState.error(
            title: 'Unavailable',
            message: 'Aiko could not read your goals right now.',
          ),
          data: (accounts) {
            final target = goal ?? _topGoal(accounts);
            if (target == null) {
              return const AikoScreenState.empty(
                title: 'No goals yet',
                message:
                    'Create a goal account with a target and date, and Aiko '
                    'will estimate your chance of reaching it.',
              );
            }
            return _ChanceBody(goal: target);
          },
        ),
      ],
    );
  }
}

class _ChanceBody extends ConsumerWidget {
  const _ChanceBody({required this.goal});

  final Account goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forecastAsync = ref.watch(goalForecastProvider(goal.id));
    return forecastAsync.when(
      loading: () => const AikoScreenState.loading(),
      error: (_, _) => const AikoScreenState.error(
        title: 'Unavailable',
        message: 'Aiko could not run the simulation right now.',
      ),
      data: (forecast) {
        if (forecast == null) {
          return const AikoScreenState.empty(
            title: 'Goal not found',
            message: 'This goal may have been deleted.',
          );
        }
        final probability = forecast.result.successProbabilityPercent;
        final currency = goal.currentBalance.currency;
        final (label, color) = switch (probability) {
          >= 70 => ('High Chance', AikoColors.successGreen),
          >= 40 => ('Fair Chance', AikoColors.warningOrange),
          _ => ('Low Chance', AikoColors.dangerRed),
        };
        final targetDate = goal.targetDate;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AikoInlineNotice(
              title: '${goal.name}: ${probability.round()}% chance',
              message: probability >= 70
                  ? 'You are on track to reach this goal.'
                  : 'Saving a bit more each month would lift your odds.',
              icon: Icons.auto_graph_outlined,
              accentColor: color,
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: AikoGauge(
                  value: (probability / 100).clamp(0.0, 1.0),
                  label: label,
                  color: color,
                ),
              ),
            ),
            AikoDataListCard(
              title: 'Projection',
              rows: [
                AikoDataRow(
                  label: 'Current Savings',
                  value: goal.currentBalance.format(),
                ),
                AikoDataRow(
                  label: 'Monthly Saving',
                  value: Money.parse(
                    forecast.monthlyContribution.toStringAsFixed(2),
                    currency,
                  ).format(),
                ),
                AikoDataRow(
                  label: 'Target Amount',
                  value: (goal.targetAmount ?? Money.zero(currency)).format(),
                ),
                AikoDataRow(
                  label: 'Target Date',
                  value: targetDate == null
                      ? 'Not set'
                      : DateFormat.yMMMd().format(targetDate),
                ),
              ],
            ),
            AikoInlineNotice(
              title: 'How this is estimated',
              message:
                  '1,000 simulations at 6% expected return and 12% volatility '
                  'over ${forecast.months} months. Estimates only, not advice.',
              icon: Icons.info_outline,
              accentColor: AikoColors.premiumPurple,
            ),
          ],
        );
      },
    );
  }
}

class MonthlyReportScreen extends ConsumerWidget {
  const MonthlyReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(monthlyReportProvider);
    return AikoDetailScaffold(
      title: 'Monthly Report',
      children: [
        reportAsync.when(
          loading: () => const AikoScreenState.loading(),
          error: (_, _) => const AikoScreenState.error(
            title: 'Report unavailable',
            message: 'Aiko could not read your transactions right now.',
          ),
          data: (report) {
            if (!report.hasActivity) {
              return const AikoScreenState.empty(
                title: 'Nothing logged yet',
                message:
                    'Add income or expenses this month and your report will '
                    'build itself here.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _reportBody(context, report),
            );
          },
        ),
      ],
    );
  }

  List<Widget> _reportBody(BuildContext context, MonthlyReport report) {
    final savedMore = report.savedVsLastMonth;
    final savedAbs = Money(
      amount: savedMore.amount.abs(),
      currency: savedMore.currency,
    );
    final headline = savedMore.isPositive
        ? 'You saved ${savedAbs.format()} more than last month.'
        : savedMore.isNegative
        ? 'You saved ${savedAbs.format()} less than last month.'
        : "Here's how this month is shaping up.";

    return [
      AikoInlineNotice(
        title: savedMore.isNegative ? 'Watch your pace' : 'This month',
        message: headline,
        icon: savedMore.isNegative
            ? Icons.trending_down
            : Icons.celebration_outlined,
        accentColor: savedMore.isNegative
            ? AikoColors.warningOrange
            : AikoColors.successGreen,
      ),
      AikoMetricGrid(
        children: [
          AikoMetricCard(
            label: 'Income',
            value: report.income.format(),
            change: _changeLabel(report.incomeChangePct),
            icon: Icons.south_west,
            accentColor: AikoColors.successGreen,
          ),
          AikoMetricCard(
            label: 'Expenses',
            value: report.expenses.format(),
            change: _changeLabel(report.expensesChangePct),
            icon: Icons.north_east,
            accentColor: AikoColors.dangerRed,
          ),
          AikoMetricCard(
            label: 'Net Cash Flow',
            value: report.netCashFlow.format(),
            change: _changeLabel(report.netChangePct),
            icon: Icons.waterfall_chart,
            accentColor: report.netCashFlow.isNegative
                ? AikoColors.dangerRed
                : AikoColors.successGreen,
          ),
          AikoMetricCard(
            label: 'Saved',
            value: report.saved.format(),
            change: '${report.savingsRatePct.toStringAsFixed(1)}% of income',
            icon: Icons.savings_outlined,
            accentColor: AikoColors.analyticsTeal,
          ),
        ],
      ),
      if (report.slices.isNotEmpty) ...[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: AikoDonutChart(
              values: report.slices
                  .map((s) => s.amount.amount.toDouble())
                  .toList(),
              colors: report.slices
                  .map((s) => aikoHexColor(s.colorHex))
                  .toList(),
              centerLabel: '${report.expenses.format()}\nTotal Expenses',
            ),
          ),
        ),
        AikoDataListCard(
          title: 'Where it went',
          rows: [
            for (final slice in report.slices)
              AikoDataRow(label: slice.name, value: slice.amount.format()),
          ],
        ),
        AikoInlineNotice(
          title: 'Top insight',
          message:
              '${report.slices.first.name} was your biggest expense at '
              '${report.slices.first.amount.format()} this month.',
          icon: Icons.lightbulb_outline,
          accentColor: AikoColors.warningOrange,
        ),
      ],
    ];
  }

  /// Signed percent, or null so the change chip is hidden when there is no
  /// prior month to compare against.
  static String? _changeLabel(double? pct) {
    if (pct == null) return null;
    final sign = pct >= 0 ? '+' : '';
    return '$sign${pct.toStringAsFixed(1)}%';
  }
}

/// Fixed palette for allocation slices, cycled by index so the donut and the
/// list agree on each asset class's color.
const _allocationPalette = [
  AikoColors.primaryBlue,
  AikoColors.analyticsTeal,
  AikoColors.premiumPurple,
  AikoColors.successGreen,
  AikoColors.warningOrange,
  AikoColors.dangerRed,
  AikoColors.deepBlue,
];

class AssetAllocationScreen extends ConsumerWidget {
  const AssetAllocationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allocationAsync = ref.watch(portfolioAllocationProvider);
    return AikoDetailScaffold(
      title: 'Asset Allocation',
      children: [
        allocationAsync.when(
          loading: () => const AikoScreenState.loading(),
          error: (_, _) => const AikoScreenState.error(
            title: 'Allocation unavailable',
            message: 'Aiko could not read your holdings right now.',
          ),
          data: (allocation) {
            if (!allocation.hasHoldings) {
              return const AikoScreenState.empty(
                title: 'No holdings yet',
                message:
                    'Add investment holdings and Aiko will break down your '
                    'allocation here.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AikoMetricCard(
                  label: 'Total Portfolio',
                  value: allocation.total.format(),
                  icon: Icons.pie_chart_outline,
                  accentColor: AikoColors.analyticsTeal,
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: AikoDonutChart(
                      values: allocation.slices
                          .map((s) => s.value.amount.toDouble())
                          .toList(),
                      colors: [
                        for (var i = 0; i < allocation.slices.length; i++)
                          _allocationPalette[i % _allocationPalette.length],
                      ],
                      centerLabel:
                          '${allocation.holdingCount}\n'
                          '${allocation.holdingCount == 1 ? 'Holding' : 'Holdings'}',
                    ),
                  ),
                ),
                AikoDataListCard(
                  title: 'Allocation',
                  rows: [
                    for (var i = 0; i < allocation.slices.length; i++)
                      AikoDataRow(
                        label: allocation.slices[i].assetClass,
                        value:
                            '${allocation.slices[i].percent.toStringAsFixed(1)}%',
                        subtitle: allocation.slices[i].value.format(),
                        color:
                            _allocationPalette[i % _allocationPalette.length],
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class HoldingDetailScreen extends ConsumerWidget {
  const HoldingDetailScreen({this.holding, super.key});

  /// Optional specific holding (passed via route `extra`). When null the screen
  /// shows the largest holding by market value.
  final InvestmentHolding? holding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holdingsAsync = ref.watch(investmentsProvider);
    return AikoDetailScaffold(
      title: 'Holding Detail',
      children: [
        holdingsAsync.when(
          loading: () => const AikoScreenState.loading(),
          error: (_, _) => const AikoScreenState.error(
            title: 'Unavailable',
            message: 'Aiko could not read your holdings right now.',
          ),
          data: (holdings) {
            final selected =
                holding ??
                (holdings.isEmpty
                    ? null
                    : holdings.reduce(
                        (a, b) =>
                            a.marketValue.compareTo(b.marketValue) >= 0 ? a : b,
                      ));
            if (selected == null) {
              return const AikoScreenState.empty(
                title: 'No holdings yet',
                message:
                    'Add an investment holding and its detail will appear here.',
              );
            }
            return _HoldingBody(holding: selected);
          },
        ),
      ],
    );
  }
}

class _HoldingBody extends StatelessWidget {
  const _HoldingBody({required this.holding});

  final InvestmentHolding holding;

  @override
  Widget build(BuildContext context) {
    final gain = holding.unrealizedGainLoss;
    final gainColor = gain.isNegative
        ? AikoColors.dangerRed
        : AikoColors.successGreen;
    final gainLabel = '${gain.isNegative ? '' : '+'}${gain.format()}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AikoMetricCard(
          label: holding.symbol,
          value: holding.currentPrice.format(),
          change: holding.assetClass,
          icon: Icons.business,
          accentColor: AikoColors.analyticsTeal,
        ),
        AikoDataListCard(
          title: 'Your Holding',
          icon: Icons.inventory_2_outlined,
          rows: [
            AikoDataRow(label: 'Shares', value: holding.quantity.toString()),
            AikoDataRow(
              label: 'Market Value',
              value: holding.marketValue.format(),
              color: AikoColors.primaryBlue,
            ),
            AikoDataRow(
              label: 'Average Cost',
              value: holding.averageCost.format(),
            ),
            AikoDataRow(
              label: 'Unrealized Gain/Loss',
              value: gainLabel,
              color: gainColor,
            ),
          ],
        ),
      ],
    );
  }
}
