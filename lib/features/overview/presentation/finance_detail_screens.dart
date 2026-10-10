import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/money/money.dart';
import '../../../l10n/domain_labels.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/layout/adaptive_presentation.dart';
import '../../../shared/widgets/aiko_data_widgets.dart';
import '../../../shared/widgets/screen_states.dart';
import '../../../theme/aiko_colors.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/presentation/account_form/account_form_screen.dart';
import '../../accounts/presentation/accounts_screen.dart';
import '../../categories/presentation/category_visual.dart';
import '../../dashboard/domain/app_notification.dart';
import '../../investments/application/investments_provider.dart';
import '../../investments/domain/investment_holding.dart';
import '../application/goal_forecast_service.dart';
import '../domain/monthly_report.dart';

/// The Retry button of an error state.
Widget _retryButton(BuildContext context, VoidCallback onRetry) =>
    FilledButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh),
      label: Text(context.l10n.retry),
    );

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
            // Rebuild the sources too: a failed load stays failed until then.
            action: _retryButton(
              context,
              () => ref
                ..invalidate(transactionsProvider)
                ..invalidate(categoriesProvider)
                ..invalidate(accountsProvider)
                ..invalidate(allNotificationsProvider),
            ),
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

class _NotificationGroupCard extends ConsumerWidget {
  const _NotificationGroupCard({
    required this.group,
    required this.notifications,
  });

  final AppNotificationGroup group;
  final List<AppNotification> notifications;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_groupIcon(group), color: AikoColors.primaryBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _groupTitle(group, context.l10n),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < notifications.length; i++) ...[
              if (i > 0) const Divider(),
              _NotificationRow(notification: notifications[i]),
            ],
          ],
        ),
      ),
    );
  }
}

/// A notification: tap opens what it's about; the close button dismisses it
/// (until the same event comes round in a new period).
class _NotificationRow extends ConsumerWidget {
  const _NotificationRow({required this.notification});

  final AppNotification notification;

  void _open(BuildContext context, WidgetRef ref) {
    switch (notification.target) {
      case AppNotificationTarget.categories:
        context.go('/categories');
      case AppNotificationTarget.accounts:
        context.go('/accounts');
      case AppNotificationTarget.account:
        final accounts = ref.read(accountsProvider).value ?? const <Account>[];
        Account? account;
        for (final candidate in accounts) {
          if (candidate.id == notification.accountId) account = candidate;
        }
        if (account == null) {
          context.go('/accounts');
        } else {
          openAikoPage<void>(context, AccountDetailScreen(account: account));
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _severityColor(notification.severity);
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _open(context, ref),
            borderRadius: BorderRadius.circular(8),
            child: AikoDataRow(
              label: notification.title,
              subtitle: notification.subtitle,
              value: '',
              color: color,
              icon: _severityIcon(notification.severity),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
        ),
        IconButton(
          tooltip: context.l10n.notifDismiss,
          icon: const Icon(Icons.close),
          onPressed: () => ref
              .read(notificationDismissalsProvider.notifier)
              .dismiss(notification.id),
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

/// Active goals, highest priority first (high > medium > low), tie-broken by
/// the nearest target date.
List<Account> _activeGoals(List<Account> accounts) {
  final goals = accounts.where((a) => a.isGoal && a.isActive).toList();
  goals.sort((a, b) {
    final byPriority = a.priority.index.compareTo(b.priority.index);
    if (byPriority != 0) return byPriority;
    final aDate = a.targetDate ?? DateTime(9999);
    final bDate = b.targetDate ?? DateTime(9999);
    return aDate.compareTo(bDate);
  });
  return goals;
}

class ChanceOfSuccessScreen extends ConsumerStatefulWidget {
  const ChanceOfSuccessScreen({this.goal, super.key});

  /// Optional goal to show first (passed via route `extra`). When null the
  /// screen starts on the top-priority goal.
  final Account? goal;

  @override
  ConsumerState<ChanceOfSuccessScreen> createState() =>
      _ChanceOfSuccessScreenState();
}

class _ChanceOfSuccessScreenState extends ConsumerState<ChanceOfSuccessScreen> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final l10n = context.l10n;
    return AikoDetailScaffold(
      title: l10n.chanceTitle,
      children: [
        accountsAsync.when(
          loading: () => const AikoScreenState.loading(),
          error: (_, _) => AikoScreenState.error(
            title: l10n.unavailable,
            message: l10n.chanceGoalsUnavailable,
            action: _retryButton(
              context,
              () => ref.invalidate(accountsProvider),
            ),
          ),
          data: (accounts) {
            final goals = _activeGoals(accounts);
            if (goals.isEmpty) {
              return AikoScreenState.empty(
                title: l10n.chanceNoGoals,
                message: l10n.chanceNoGoalsMessage,
              );
            }
            final wanted = _selectedId ?? widget.goal?.id;
            // Otherwise the top goal that can be forecast, else the top goal.
            const service = GoalForecastService();
            final now = DateTime.now();
            final goal = goals.firstWhere(
              (g) => g.id == wanted,
              orElse: () => goals.firstWhere(
                (g) => service.blockerFor(g, now) == null,
                orElse: () => goals.first,
              ),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (goals.length > 1) ...[
                  DropdownButtonFormField<String>(
                    key: ValueKey('chance-goal-${goal.id}'),
                    initialValue: goal.id,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.chanceSelectGoal,
                      prefixIcon: const Icon(Icons.flag_outlined),
                    ),
                    items: [
                      for (final g in goals)
                        DropdownMenuItem(
                          value: g.id,
                          child: Text(g.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (id) => setState(() => _selectedId = id),
                  ),
                  const SizedBox(height: 12),
                ],
                _ChanceBody(goalId: goal.id),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ChanceBody extends ConsumerWidget {
  const _ChanceBody({required this.goalId});

  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outcomeAsync = ref.watch(goalForecastProvider(goalId));
    final l10n = context.l10n;
    return outcomeAsync.when(
      loading: () => const AikoScreenState.loading(),
      error: (_, _) => AikoScreenState.error(
        title: l10n.unavailable,
        message: l10n.chanceSimulationFailed,
        action: _retryButton(context, () {
          ref
            ..invalidate(transactionsProvider)
            ..invalidate(goalForecastProvider(goalId));
        }),
      ),
      data: (outcome) {
        if (outcome == null) {
          return AikoScreenState.empty(
            title: l10n.chanceGoalNotFound,
            message: l10n.chanceGoalDeleted,
          );
        }
        final goal = outcome.goal;
        final forecast = outcome.forecast;
        if (forecast == null) {
          final (title, message) = _blockerText(goal, outcome.blocker!, l10n);
          return AikoScreenState.empty(
            title: title,
            message: message,
            action: FilledButton.icon(
              onPressed: () => openAikoPage<Account>(
                context,
                AccountFormScreen(account: goal),
              ),
              icon: const Icon(Icons.edit_outlined),
              label: Text(l10n.chanceEditGoal),
            ),
          );
        }
        return _ChanceResult(goal: goal, forecast: forecast);
      },
    );
  }

  static (String, String) _blockerText(
    Account goal,
    GoalForecastBlocker blocker,
    AppLocalizations l10n,
  ) => switch (blocker) {
    GoalForecastBlocker.missingTarget => (
      l10n.chanceNeedsTargetTitle,
      l10n.chanceNeedsTargetMessage(goal.name),
    ),
    GoalForecastBlocker.missingTargetDate => (
      l10n.chanceNeedsDateTitle,
      l10n.chanceNeedsDateMessage(goal.name),
    ),
    GoalForecastBlocker.missingTargetAndDate => (
      l10n.chanceNeedsTargetAndDateTitle,
      l10n.chanceNeedsTargetAndDateMessage(goal.name),
    ),
    GoalForecastBlocker.targetDatePassed => (
      l10n.chanceDatePassedTitle,
      l10n.chanceDatePassedMessage(
        goal.name,
        DateFormat.yMMMd().format(goal.targetDate!),
      ),
    ),
  };
}

class _ChanceResult extends StatelessWidget {
  const _ChanceResult({required this.goal, required this.forecast});

  final Account goal;
  final GoalForecast forecast;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final probability = forecast.result.successProbabilityPercent;
    final currency = goal.currentBalance.currency;
    final (label, color) = switch (probability) {
      >= 70 => (l10n.chanceHigh, AikoColors.successGreen),
      >= 40 => (l10n.chanceFair, AikoColors.warningOrange),
      _ => (l10n.chanceLow, AikoColors.dangerRed),
    };
    final reached = goal.goalRemaining.isZero;
    final targetDate = goal.targetDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AikoInlineNotice(
          title: l10n.chanceGoalTitle(goal.name, probability.round()),
          message: probability >= 70 ? l10n.chanceOnTrack : l10n.chanceSaveMore,
          icon: Icons.auto_graph_outlined,
          accentColor: color,
        ),
        if (!reached && forecast.monthlyContribution <= 0)
          AikoInlineNotice(
            title: l10n.chanceNoRecentDepositsTitle,
            message: l10n.chanceNoRecentDeposits(
              GoalForecastService.contributionWindowMonths,
            ),
            icon: Icons.savings_outlined,
            accentColor: AikoColors.warningOrange,
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
          title: l10n.chanceProjection,
          rows: [
            AikoDataRow(
              label: l10n.chanceCurrentSavings,
              value: goal.currentBalance.format(),
            ),
            AikoDataRow(
              label: l10n.chanceMonthlySaving,
              value: Money.parse(
                forecast.monthlyContribution.toStringAsFixed(2),
                currency,
              ).format(),
            ),
            AikoDataRow(
              label: l10n.chanceTargetAmount,
              value: (goal.targetAmount ?? Money.zero(currency)).format(),
            ),
            AikoDataRow(
              label: l10n.chanceTargetDate,
              value: targetDate == null
                  ? l10n.notSet
                  : DateFormat.yMMMd().format(targetDate),
            ),
          ],
        ),
        AikoInlineNotice(
          title: l10n.chanceHowEstimated,
          message: l10n.chanceMethod(
            forecast.months,
            GoalForecastService.contributionWindowMonths,
          ),
          icon: Icons.info_outline,
          accentColor: AikoColors.premiumPurple,
        ),
      ],
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
            action: _retryButton(
              context,
              () => ref
                ..invalidate(transactionsProvider)
                ..invalidate(categoriesProvider)
                ..invalidate(monthlyReportProvider),
            ),
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
            changeColor: _changeColor(
              context,
              report.incomeChangePct,
              higherIsBetter: true,
            ),
            icon: Icons.south_west,
            accentColor: AikoColors.successGreen,
          ),
          AikoMetricCard(
            label: context.l10n.reportExpenses,
            value: report.expenses.format(),
            change: _changeLabel(report.expensesChangePct),
            changeColor: _changeColor(
              context,
              report.expensesChangePct,
              higherIsBetter: false,
            ),
            icon: Icons.north_east,
            accentColor: AikoColors.dangerRed,
          ),
          AikoMetricCard(
            label: context.l10n.reportNetCashFlow,
            value: report.netCashFlow.format(),
            change: _changeLabel(report.netChangePct),
            changeColor: _changeColor(
              context,
              report.netChangePct,
              higherIsBetter: true,
            ),
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

  /// Green when the change is good news (income or net up, spending down),
  /// red when it's bad, muted when flat.
  static Color? _changeColor(
    BuildContext context,
    double? pct, {
    required bool higherIsBetter,
  }) {
    if (pct == null) return null;
    return switch (changeTone(pct, higherIsBetter: higherIsBetter)) {
      ChangeTone.good => AikoColors.successGreen,
      ChangeTone.bad => AikoColors.dangerRed,
      ChangeTone.flat => Theme.of(context).colorScheme.onSurfaceVariant,
    };
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
            action: _retryButton(
              context,
              () => ref
                ..invalidate(investmentsProvider)
                ..invalidate(portfolioAllocationProvider),
            ),
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
                      centerLabel: context.l10n.holdingsCount(
                        allocation.holdingCount,
                      ),
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

class HoldingDetailScreen extends ConsumerStatefulWidget {
  const HoldingDetailScreen({this.holding, this.holdingId, super.key});

  /// Optional holding to show first (passed via route `extra`).
  final InvestmentHolding? holding;

  /// Optional id of the holding to show first (the route's `id` query
  /// parameter, so the link survives a reload). Without either, the screen
  /// starts on the largest holding by market value.
  final String? holdingId;

  @override
  ConsumerState<HoldingDetailScreen> createState() =>
      _HoldingDetailScreenState();
}

class _HoldingDetailScreenState extends ConsumerState<HoldingDetailScreen> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final holdingsAsync = ref.watch(investmentsProvider);
    final l10n = context.l10n;
    return AikoDetailScaffold(
      title: l10n.toolHoldingDetail,
      children: [
        holdingsAsync.when(
          loading: () => const AikoScreenState.loading(),
          error: (_, _) => AikoScreenState.error(
            title: l10n.unavailable,
            message: l10n.holdingsUnavailableMessage,
            action: _retryButton(
              context,
              () => ref.invalidate(investmentsProvider),
            ),
          ),
          data: (holdings) {
            if (holdings.isEmpty) {
              return AikoScreenState.empty(
                title: l10n.holdingsEmptyTitle,
                message: l10n.holdingDetailEmptyMessage,
              );
            }
            // Largest first, so the default is the biggest position.
            final sorted = [...holdings]
              ..sort(
                (a, b) => b.marketValue.amount.compareTo(a.marketValue.amount),
              );
            final wanted =
                _selectedId ?? widget.holdingId ?? widget.holding?.id;
            final selected = sorted.firstWhere(
              (h) => h.id == wanted,
              orElse: () => sorted.first,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (sorted.length > 1) ...[
                  DropdownButtonFormField<String>(
                    key: ValueKey('holding-${selected.id}'),
                    initialValue: selected.id,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.holdingSelectLabel,
                      prefixIcon: const Icon(Icons.inventory_2_outlined),
                    ),
                    items: [
                      for (final h in sorted)
                        DropdownMenuItem(
                          value: h.id,
                          child: Text(
                            h.symbol,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (id) => setState(() => _selectedId = id),
                  ),
                  const SizedBox(height: 12),
                ],
                _HoldingBody(holding: selected),
              ],
            );
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
