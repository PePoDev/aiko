import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/widgets/aiko_data_widgets.dart';
import '../../../theme/aiko_colors.dart';

class NotificationsCenterScreen extends StatelessWidget {
  const NotificationsCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AikoDetailScaffold(
      title: 'Notifications',
      actions: [
        TextButton(
          onPressed: () =>
              _showSnack(context, 'All notifications marked read.'),
          child: const Text('Mark all'),
        ),
      ],
      children: const [
        _SegmentedHeader(labels: ['All', 'Alerts', 'Updates']),
        AikoDataListCard(
          title: 'Today',
          icon: Icons.notifications_none,
          rows: [
            AikoDataRow(
              label: 'Budget alert',
              subtitle: 'You have used 80% of Food & Dining.',
              value: '9:30 AM',
              color: AikoColors.warningOrange,
              icon: Icons.warning_amber_outlined,
            ),
            AikoDataRow(
              label: 'Goal progress',
              subtitle: 'Vacation 2025 is 50% complete.',
              value: '8:15 AM',
              color: AikoColors.successGreen,
              icon: Icons.flag_outlined,
            ),
            AikoDataRow(
              label: 'Account linked',
              subtitle: 'Chase Checking was connected.',
              value: '7:45 AM',
              icon: Icons.account_balance_outlined,
            ),
          ],
        ),
        AikoDataListCard(
          title: 'Yesterday',
          icon: Icons.history,
          rows: [
            AikoDataRow(
              label: 'Recurring reminder',
              subtitle: 'Netflix renews soon.',
              value: '9:00 PM',
              color: AikoColors.premiumPurple,
              icon: Icons.receipt_long_outlined,
            ),
            AikoDataRow(
              label: 'Weekly summary',
              subtitle: 'Your weekly spending summary is ready.',
              value: '6:30 PM',
              icon: Icons.summarize_outlined,
            ),
          ],
        ),
      ],
    );
  }
}

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

class LoanCalculatorScreen extends StatefulWidget {
  const LoanCalculatorScreen({super.key});

  @override
  State<LoanCalculatorScreen> createState() => _LoanCalculatorScreenState();
}

class _LoanCalculatorScreenState extends State<LoanCalculatorScreen> {
  double _amount = 200000;
  double _rate = 6.5;
  double _years = 20;
  bool _reduceTenure = true;

  double get _emi {
    final monthlyRate = _rate / 100 / 12;
    final months = _years * 12;
    final factor = math.pow(1 + monthlyRate, months);
    return _amount * monthlyRate * factor / (factor - 1);
  }

  @override
  Widget build(BuildContext context) {
    return AikoDetailScaffold(
      title: 'Loan Calculator',
      children: [
        const _SegmentedHeader(labels: ['EMI', 'Total Interest']),
        _SliderCard(
          label: 'Loan Amount',
          valueLabel: '\$${_amount.toStringAsFixed(0)}',
          min: 5000,
          max: 500000,
          value: _amount,
          onChanged: (value) => setState(() => _amount = value),
        ),
        _SliderCard(
          label: 'Interest Rate (p.a.)',
          valueLabel: '${_rate.toStringAsFixed(2)}%',
          min: 1,
          max: 18,
          value: _rate,
          onChanged: (value) => setState(() => _rate = value),
        ),
        _SliderCard(
          label: 'Loan Tenure',
          valueLabel: '${_years.toStringAsFixed(0)} years',
          min: 1,
          max: 30,
          value: _years,
          onChanged: (value) => setState(() => _years = value),
        ),
        SwitchListTile(
          value: _reduceTenure,
          title: const Text('Reduce Tenure'),
          subtitle: const Text('Apply prepayments to finish faster'),
          onChanged: (value) => setState(() => _reduceTenure = value),
        ),
        AikoMetricCard(
          label: 'Estimated Monthly EMI',
          value: '\$${_emi.toStringAsFixed(2)}',
          change: 'Based on current inputs',
          icon: Icons.calculate_outlined,
        ),
        FilledButton.icon(
          onPressed: () => _showSnack(context, 'Loan scenario calculated.'),
          icon: const Icon(Icons.calculate_outlined),
          label: const Text('Calculate'),
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

class ProfileSecurityScreen extends StatefulWidget {
  const ProfileSecurityScreen({super.key});

  @override
  State<ProfileSecurityScreen> createState() => _ProfileSecurityScreenState();
}

class _ProfileSecurityScreenState extends State<ProfileSecurityScreen> {
  bool _twoFactor = true;
  bool _biometric = true;
  bool _alerts = true;

  @override
  Widget build(BuildContext context) {
    return AikoDetailScaffold(
      title: 'Profile & Security',
      children: [
        const AikoInlineNotice(
          title: 'Aiko Finance',
          message: 'hello@aiko.finance, +1 (555) 121-4567',
          icon: Icons.person_outline,
        ),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Change Password'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showSnack(context, 'Password flow opened.'),
              ),
              const Divider(),
              SwitchListTile(
                value: _twoFactor,
                title: const Text('Two-Factor Authentication'),
                secondary: const Icon(Icons.verified_user_outlined),
                onChanged: (value) => setState(() => _twoFactor = value),
              ),
              SwitchListTile(
                value: _biometric,
                title: const Text('Biometric Login'),
                secondary: const Icon(Icons.fingerprint),
                onChanged: (value) => setState(() => _biometric = value),
              ),
              SwitchListTile(
                value: _alerts,
                title: const Text('Login Alerts'),
                secondary: const Icon(Icons.notifications_active_outlined),
                onChanged: (value) => setState(() => _alerts = value),
              ),
            ],
          ),
        ),
        const AikoInlineNotice(
          title: 'Account Security Score',
          message: 'Strong, all account protections are active.',
          icon: Icons.shield_outlined,
          accentColor: AikoColors.successGreen,
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

class _SliderCard extends StatelessWidget {
  const _SliderCard({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Text(label)),
                Text(valueLabel, style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            Slider(value: value, min: min, max: max, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
