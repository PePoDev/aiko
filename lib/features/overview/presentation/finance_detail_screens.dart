import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/money/money.dart';
import '../../../l10n/domain_labels.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/aiko_data_widgets.dart';
import '../../../shared/widgets/screen_states.dart';
import '../../../theme/aiko_colors.dart';
import '../../accounts/domain/account.dart';
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
      title: context.l10n.notificationsTitle,
      children: [
        notificationsAsync.when(
          loading: () => const AikoScreenState.loading(),
          error: (_, _) => AikoScreenState.error(
            title: context.l10n.notifUnavailableTitle,
            message: context.l10n.notifUnavailableMessage,
          ),
          data: (notifications) {
            if (notifications.isEmpty) {
              return AikoScreenState.empty(
                title: context.l10n.notifAllCaughtUp,
                message: context.l10n.notifAllCaughtUpMessage,
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
      title: _groupTitle(group, context.l10n),
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

String _groupTitle(AppNotificationGroup group, AppLocalizations l10n) =>
    switch (group) {
      AppNotificationGroup.budget => l10n.notifGroupBudget,
      AppNotificationGroup.bills => l10n.notifGroupBills,
      AppNotificationGroup.goals => l10n.notifGroupGoals,
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
      title: context.l10n.chanceTitle,
      children: [
        accountsAsync.when(
          loading: () => const AikoScreenState.loading(),
          error: (_, _) => AikoScreenState.error(
            title: context.l10n.unavailable,
            message: context.l10n.chanceGoalsUnavailable,
          ),
          data: (accounts) {
            final target = goal ?? _topGoal(accounts);
            if (target == null) {
              return AikoScreenState.empty(
                title: context.l10n.chanceNoGoals,
                message: context.l10n.chanceNoGoalsMessage,
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
      error: (_, _) => AikoScreenState.error(
        title: context.l10n.unavailable,
        message: context.l10n.chanceSimulationFailed,
      ),
      data: (forecast) {
        if (forecast == null) {
          return AikoScreenState.empty(
            title: context.l10n.chanceGoalNotFound,
            message: context.l10n.chanceGoalDeleted,
          );
        }
        final probability = forecast.result.successProbabilityPercent;
        final currency = goal.currentBalance.currency;
        final (label, color) = switch (probability) {
          >= 70 => (context.l10n.chanceHigh, AikoColors.successGreen),
          >= 40 => (context.l10n.chanceFair, AikoColors.warningOrange),
          _ => (context.l10n.chanceLow, AikoColors.dangerRed),
        };
        final targetDate = goal.targetDate;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AikoInlineNotice(
              title: context.l10n.chanceGoalTitle(
                goal.name,
                probability.round(),
              ),
              message: probability >= 70
                  ? context.l10n.chanceOnTrack
                  : context.l10n.chanceSaveMore,
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
              title: context.l10n.chanceProjection,
              rows: [
                AikoDataRow(
                  label: context.l10n.chanceCurrentSavings,
                  value: goal.currentBalance.format(),
                ),
                AikoDataRow(
                  label: context.l10n.chanceMonthlySaving,
                  value: Money.parse(
                    forecast.monthlyContribution.toStringAsFixed(2),
                    currency,
                  ).format(),
                ),
                AikoDataRow(
                  label: context.l10n.chanceTargetAmount,
                  value: (goal.targetAmount ?? Money.zero(currency)).format(),
                ),
                AikoDataRow(
                  label: context.l10n.chanceTargetDate,
                  value: targetDate == null
                      ? context.l10n.notSet
                      : DateFormat.yMMMd().format(targetDate),
                ),
              ],
            ),
            AikoInlineNotice(
              title: context.l10n.chanceHowEstimated,
              message: context.l10n.chanceMethod(forecast.months),
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
      title: context.l10n.reportTitle,
      children: [
        reportAsync.when(
          loading: () => const AikoScreenState.loading(),
          error: (_, _) => AikoScreenState.error(
            title: context.l10n.reportUnavailable,
            message: context.l10n.reportTransactionsUnavailable,
          ),
          data: (report) {
            if (!report.hasActivity) {
              return AikoScreenState.empty(
                title: context.l10n.reportNothingLogged,
                message: context.l10n.reportNothingLoggedMessage,
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
    final l10n = context.l10n;
    final headline = savedMore.isPositive
        ? l10n.reportSavedMore(savedAbs.format())
        : savedMore.isNegative
        ? l10n.reportSavedLess(savedAbs.format())
        : l10n.reportShapingUp;

    return [
      AikoInlineNotice(
        title: savedMore.isNegative
            ? context.l10n.reportWatchPace
            : context.l10n.txFilterThisMonth,
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
            label: context.l10n.transactionTypeIncome,
            value: report.income.format(),
            change: _changeLabel(report.incomeChangePct),
            icon: Icons.south_west,
            accentColor: AikoColors.successGreen,
          ),
          AikoMetricCard(
            label: context.l10n.reportExpenses,
            value: report.expenses.format(),
            change: _changeLabel(report.expensesChangePct),
            icon: Icons.north_east,
            accentColor: AikoColors.dangerRed,
          ),
          AikoMetricCard(
            label: context.l10n.reportNetCashFlow,
            value: report.netCashFlow.format(),
            change: _changeLabel(report.netChangePct),
            icon: Icons.waterfall_chart,
            accentColor: report.netCashFlow.isNegative
                ? AikoColors.dangerRed
                : AikoColors.successGreen,
          ),
          AikoMetricCard(
            label: context.l10n.reportSaved,
            value: report.saved.format(),
            change: context.l10n.reportOfIncome(
              report.savingsRatePct.toStringAsFixed(1),
            ),
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
              centerLabel: l10n.reportTotalExpensesCenter(
                report.expenses.format(),
              ),
            ),
          ),
        ),
        AikoDataListCard(
          title: context.l10n.reportWhereItWent,
          rows: [
            for (final slice in report.slices)
              AikoDataRow(label: slice.name, value: slice.amount.format()),
          ],
        ),
        AikoInlineNotice(
          title: context.l10n.reportTopInsight,
          message: l10n.reportTopInsightMessage(
            report.slices.first.name,
            report.slices.first.amount.format(),
          ),
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
      title: context.l10n.toolAssetAllocation,
      children: [
        allocationAsync.when(
          loading: () => const AikoScreenState.loading(),
          error: (_, _) => AikoScreenState.error(
            title: context.l10n.allocationUnavailable,
            message: context.l10n.holdingsUnavailableMessage,
          ),
          data: (allocation) {
            if (!allocation.hasHoldings) {
              return AikoScreenState.empty(
                title: context.l10n.holdingsEmptyTitle,
                message: context.l10n.allocationEmptyMessage,
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AikoMetricCard(
                  label: context.l10n.allocationTotalPortfolio,
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
                  title: context.l10n.allocationTitle,
                  rows: [
                    for (var i = 0; i < allocation.slices.length; i++)
                      AikoDataRow(
                        label: investmentAssetClassLabel(
                          allocation.slices[i].assetClass,
                          context.l10n,
                        ),
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
      title: context.l10n.toolHoldingDetail,
      children: [
        holdingsAsync.when(
          loading: () => const AikoScreenState.loading(),
          error: (_, _) => AikoScreenState.error(
            title: context.l10n.unavailable,
            message: context.l10n.holdingsUnavailableMessage,
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
              return AikoScreenState.empty(
                title: context.l10n.holdingsEmptyTitle,
                message: context.l10n.holdingDetailEmptyMessage,
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
          change: investmentAssetClassLabel(holding.assetClass, context.l10n),
          icon: Icons.business,
          accentColor: AikoColors.analyticsTeal,
        ),
        AikoDataListCard(
          title: context.l10n.holdingYourHolding,
          icon: Icons.inventory_2_outlined,
          rows: [
            AikoDataRow(
              label: context.l10n.holdingShares,
              value: holding.quantity.toString(),
            ),
            AikoDataRow(
              label: context.l10n.holdingMarketValue,
              value: holding.marketValue.format(),
              color: AikoColors.primaryBlue,
            ),
            AikoDataRow(
              label: context.l10n.holdingAverageCost,
              value: holding.averageCost.format(),
            ),
            AikoDataRow(
              label: context.l10n.holdingUnrealizedGainLoss,
              value: gainLabel,
              color: gainColor,
            ),
          ],
        ),
      ],
    );
  }
}
