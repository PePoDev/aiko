import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/aiko_data_widgets.dart';
import '../../../shared/widgets/screen_states.dart';
import '../../../theme/aiko_colors.dart';
import '../../dashboard/domain/app_notification.dart';

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

class PaceOverviewScreen extends StatelessWidget {
  const PaceOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AikoDetailScaffold(
      title: 'Pace Overview',
      children: [
        AikoInlineNotice(
          title: 'You are on track',
          message: 'You spent \$120 less than planned so far this month.',
          icon: Icons.speed_outlined,
          accentColor: AikoColors.successGreen,
        ),
        AikoMetricCard(
          label: 'Overall Pace',
          value: '92%',
          change: '\$130 under planned pace',
          icon: Icons.route_outlined,
          accentColor: AikoColors.successGreen,
          progress: 0.92,
        ),
        AikoDataListCard(
          title: 'Category Pace',
          icon: Icons.category_outlined,
          rows: [
            AikoDataRow(
              label: 'Housing',
              value: '81%',
              color: AikoColors.successGreen,
            ),
            AikoDataRow(
              label: 'Food & Dining',
              value: '95%',
              color: AikoColors.warningOrange,
            ),
            AikoDataRow(
              label: 'Transport',
              value: '88%',
              color: AikoColors.successGreen,
            ),
            AikoDataRow(
              label: 'Lifestyle',
              value: '110%',
              color: AikoColors.dangerRed,
            ),
            AikoDataRow(
              label: 'Other',
              value: '60%',
              color: AikoColors.successGreen,
            ),
          ],
        ),
      ],
    );
  }
}

class SafeToSpendScreen extends StatelessWidget {
  const SafeToSpendScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AikoDetailScaffold(
      title: 'Safe to Spend',
      children: [
        AikoMetricCard(
          label: 'Safe to Spend',
          value: '\$1,235.00',
          change: 'Leftover for 12 days',
          icon: Icons.savings_outlined,
          accentColor: AikoColors.primaryBlue,
        ),
        AikoDataListCard(
          title: 'Breakdown',
          icon: Icons.list_alt_outlined,
          rows: [
            AikoDataRow(
              label: 'Income',
              value: '\$5,320.00',
              color: AikoColors.successGreen,
            ),
            AikoDataRow(
              label: 'Recurring payments',
              value: '-\$1,950.00',
              color: AikoColors.dangerRed,
            ),
            AikoDataRow(
              label: 'Savings Goals',
              value: '-\$1,000.00',
              color: AikoColors.analyticsTeal,
            ),
            AikoDataRow(
              label: 'Planned Spending',
              value: '-\$1,135.00',
              color: AikoColors.warningOrange,
            ),
            AikoDataRow(
              label: 'Leftover',
              value: '\$1,235.00',
              color: AikoColors.successGreen,
            ),
          ],
        ),
        AikoMetricCard(
          label: 'Daily Safe to Spend',
          value: '\$102.92',
          change: 'Average per day',
          icon: Icons.today_outlined,
        ),
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: AikoMiniBarChart(
              values: [22, 35, 30, 42, 28, 55, 47, 38, 44, 58, 34, 49],
            ),
          ),
        ),
      ],
    );
  }
}

class CashFlowOverviewScreen extends StatelessWidget {
  const CashFlowOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AikoDetailScaffold(
      title: 'Cash Flow',
      children: [
        AikoMetricCard(
          label: 'Net Cash Flow',
          value: '\$1,230.00',
          change: '+\$320 vs last month',
          icon: Icons.waterfall_chart,
          accentColor: AikoColors.successGreen,
        ),
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: AikoMiniBarChart(
              values: [18, 20, 28, 24, 34, 39, 36, 42, 44, 48, 54, 62],
              color: AikoColors.successGreen,
            ),
          ),
        ),
        AikoDataListCard(
          title: 'Cash Flow Summary',
          icon: Icons.account_tree_outlined,
          rows: [
            AikoDataRow(
              label: 'Income',
              value: '\$5,320.00',
              color: AikoColors.successGreen,
            ),
            AikoDataRow(
              label: 'Expenses',
              value: '-\$4,090.00',
              color: AikoColors.dangerRed,
            ),
            AikoDataRow(
              label: 'Savings & Goals',
              value: '-\$1,000.00',
              color: AikoColors.analyticsTeal,
            ),
            AikoDataRow(
              label: 'Investments',
              value: '-\$1,000.00',
              color: AikoColors.warningOrange,
            ),
            AikoDataRow(
              label: 'Net Cash Flow',
              value: '\$1,230.00',
              color: AikoColors.successGreen,
            ),
          ],
        ),
      ],
    );
  }
}

class CashFlowSankeyScreen extends StatelessWidget {
  const CashFlowSankeyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AikoDetailScaffold(
      title: 'Cash Flow Sankey',
      children: [
        _SegmentedHeader(labels: ['Sankey View', 'Category View']),
        Card(
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
              value: '\$5,320',
              color: AikoColors.successGreen,
            ),
            AikoDataRow(
              label: 'Needs',
              value: '\$2,400',
              color: AikoColors.primaryBlue,
            ),
            AikoDataRow(
              label: 'Wants',
              value: '\$1,200',
              color: AikoColors.warningOrange,
            ),
            AikoDataRow(
              label: 'Savings',
              value: '\$1,000',
              color: AikoColors.analyticsTeal,
            ),
            AikoDataRow(
              label: 'Debt',
              value: '\$700',
              color: AikoColors.dangerRed,
            ),
          ],
        ),
      ],
    );
  }
}

class SavingPlanScreen extends StatefulWidget {
  const SavingPlanScreen({super.key});

  @override
  State<SavingPlanScreen> createState() => _SavingPlanScreenState();
}

class _SavingPlanScreenState extends State<SavingPlanScreen> {
  final Map<String, bool> _plans = {
    'Auto-Save (General)': true,
    'Emergency Fund': true,
    'Vacation 2025': true,
    'New Laptop': false,
  };

  @override
  Widget build(BuildContext context) {
    return AikoDetailScaffold(
      title: 'Saving Plan',
      children: [
        const AikoInlineNotice(
          title: 'Plan today, achieve tomorrow',
          message: 'Aiko keeps contributions consistent without surprises.',
          icon: Icons.savings_outlined,
        ),
        Card(
          child: Column(
            children: [
              for (final plan in _plans.entries)
                SwitchListTile(
                  value: plan.value,
                  title: Text(plan.key),
                  subtitle: Text(plan.value ? 'Active' : 'Paused'),
                  secondary: const Icon(Icons.savings_outlined),
                  onChanged: (value) =>
                      setState(() => _plans[plan.key] = value),
                ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: () => _showSnack(context, 'New saving plan started.'),
          icon: const Icon(Icons.add),
          label: const Text('Create New Plan'),
        ),
      ],
    );
  }
}

class ChanceOfSuccessScreen extends StatelessWidget {
  const ChanceOfSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AikoDetailScaffold(
      title: 'Chance of Success',
      children: [
        AikoInlineNotice(
          title: 'Great progress',
          message: 'You are on track to reach this goal.',
          icon: Icons.auto_graph_outlined,
          accentColor: AikoColors.successGreen,
        ),
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: AikoGauge(value: 0.78, label: 'High Chance'),
          ),
        ),
        AikoDataListCard(
          title: 'Projection',
          rows: [
            AikoDataRow(label: 'Current Savings', value: '\$1,250.00'),
            AikoDataRow(label: 'Monthly Saving', value: '\$250.00'),
            AikoDataRow(label: 'Target Amount', value: '\$2,500.00'),
            AikoDataRow(label: 'Target Date', value: 'Aug 31, 2026'),
          ],
        ),
      ],
    );
  }
}

class MonthlyReportScreen extends StatelessWidget {
  const MonthlyReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return AikoDetailScaffold(
      title: 'Monthly Report',
      children: [
        AikoInlineNotice(
          title: 'Great month',
          message: 'You saved \$320 more than last month.',
          icon: Icons.celebration_outlined,
          accentColor: AikoColors.successGreen,
        ),
        AikoMetricGrid(
          children: [
            AikoMetricCard(
              label: 'Income',
              value: '\$5,320',
              change: '+8.5%',
              icon: Icons.south_west,
              accentColor: AikoColors.successGreen,
            ),
            AikoMetricCard(
              label: 'Expenses',
              value: '\$4,090',
              change: '-5.2%',
              icon: Icons.north_east,
              accentColor: AikoColors.dangerRed,
            ),
            AikoMetricCard(
              label: 'Net Cash Flow',
              value: '\$1,230',
              change: '+32.0%',
              icon: Icons.waterfall_chart,
              accentColor: AikoColors.successGreen,
            ),
            AikoMetricCard(
              label: 'Saved',
              value: '\$1,000',
              change: '18.8%',
              icon: Icons.savings_outlined,
              accentColor: AikoColors.analyticsTeal,
            ),
          ],
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: AikoDonutChart(
              values: [35, 18, 8, 19, 20],
              colors: [
                AikoColors.primaryBlue,
                AikoColors.analyticsTeal,
                AikoColors.warningOrange,
                AikoColors.premiumPurple,
                mutedColor,
              ],
              centerLabel: '\$4,090\nTotal Expenses',
            ),
          ),
        ),
        AikoInlineNotice(
          title: 'Top insight',
          message:
              'Lifestyle spending increased by 12% compared to last month.',
          icon: Icons.lightbulb_outline,
          accentColor: AikoColors.warningOrange,
        ),
      ],
    );
  }
}

class AssetAllocationScreen extends StatelessWidget {
  const AssetAllocationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AikoDetailScaffold(
      title: 'Asset Allocation',
      children: [
        AikoMetricCard(
          label: 'Total Portfolio',
          value: '\$102,450.00',
          icon: Icons.pie_chart_outline,
          accentColor: AikoColors.analyticsTeal,
        ),
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: AikoDonutChart(
              values: [68.5, 18.2, 6.0, 4.5, 2.8],
              colors: [
                AikoColors.primaryBlue,
                AikoColors.analyticsTeal,
                AikoColors.premiumPurple,
                AikoColors.successGreen,
                AikoColors.warningOrange,
              ],
              centerLabel: '42\nHoldings',
            ),
          ),
        ),
        AikoDataListCard(
          title: 'Allocation',
          rows: [
            AikoDataRow(
              label: 'Stocks',
              value: '68.5%',
              color: AikoColors.primaryBlue,
            ),
            AikoDataRow(
              label: 'Bonds',
              value: '18.2%',
              color: AikoColors.analyticsTeal,
            ),
            AikoDataRow(
              label: 'Cash',
              value: '6.0%',
              color: AikoColors.premiumPurple,
            ),
            AikoDataRow(
              label: 'Real Estate',
              value: '4.5%',
              color: AikoColors.successGreen,
            ),
            AikoDataRow(
              label: 'Commodities',
              value: '2.8%',
              color: AikoColors.warningOrange,
            ),
          ],
        ),
        AikoInlineNotice(
          title: 'Great balance',
          message: 'Your portfolio is well diversified.',
          icon: Icons.auto_awesome,
        ),
      ],
    );
  }
}

class HoldingDetailScreen extends StatelessWidget {
  const HoldingDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AikoDetailScaffold(
      title: 'Holding Detail',
      children: [
        const AikoMetricCard(
          label: 'Apple Inc.',
          value: '\$195.74',
          change: '+\$2.35 today',
          icon: Icons.business,
          accentColor: AikoColors.successGreen,
        ),
        const AikoDataListCard(
          title: 'Your Holding',
          icon: Icons.inventory_2_outlined,
          rows: [
            AikoDataRow(label: 'Shares', value: '25'),
            AikoDataRow(
              label: 'Market Value',
              value: '\$4,893.50',
              color: AikoColors.successGreen,
            ),
            AikoDataRow(label: 'Average Cost', value: '\$168.20'),
            AikoDataRow(
              label: 'Total Gain',
              value: '+\$687.00',
              color: AikoColors.successGreen,
            ),
          ],
        ),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: AikoMiniBarChart(
              values: [
                150,
                155,
                148,
                164,
                172,
                168,
                181,
                176,
                188,
                193,
                190,
                196,
              ],
              color: AikoColors.primaryBlue,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: () => _showSnack(context, 'Buy flow opened.'),
                child: const Text('Buy'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _showSnack(context, 'Sell flow opened.'),
                child: const Text('Sell'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}



class _SegmentedHeader extends StatelessWidget {
  const _SegmentedHeader({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      segments: [
        for (var index = 0; index < labels.length; index++)
          ButtonSegment(value: index, label: Text(labels[index])),
      ],
      selected: const {0},
      onSelectionChanged: (_) {},
    );
  }
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
