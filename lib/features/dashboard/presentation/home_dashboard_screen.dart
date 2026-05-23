import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/money/money.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../shared/widgets/screen_states.dart';
import '../../../theme/aiko_colors.dart';
import '../../budgets/presentation/budget_form_screen.dart';
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
                summary.paceStatus.isFast
                    ? l10n.paceAhead
                    : l10n.paceOnTrack,
              ),
            ),
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

class _QuickAddMenu extends StatefulWidget {
  const _QuickAddMenu();

  @override
  State<_QuickAddMenu> createState() => _QuickAddMenuState();
}

class _QuickAddMenuState extends State<_QuickAddMenu> {
  var _isOpen = false;

  void _toggle() {
    setState(() => _isOpen = !_isOpen);
  }

  void _openAddPage(Widget page) {
    setState(() => _isOpen = false);
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: _isOpen
              ? Column(
                  key: const ValueKey('quick-add-options'),
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _QuickAddOption(
                      heroTag: 'quick-add-transaction',
                      icon: Icons.receipt_long_outlined,
                      label: l10n.addTransaction,
                      onPressed: () =>
                          _openAddPage(const TransactionFormScreen()),
                    ),
                    const SizedBox(height: 8),
                    _QuickAddOption(
                      heroTag: 'quick-add-budget',
                      icon: Icons.pie_chart_outline,
                      label: l10n.addBudget,
                      onPressed: () => _openAddPage(const BudgetFormScreen()),
                    ),
                    const SizedBox(height: 12),
                  ],
                )
              : const SizedBox.shrink(key: ValueKey('quick-add-empty')),
        ),
        FloatingActionButton.extended(
          heroTag: 'quick-add-main',
          onPressed: _toggle,
          icon: Icon(_isOpen ? Icons.close : Icons.add),
          label: Text(_isOpen ? l10n.close : l10n.quickAdd),
        ),
      ],
    );
  }
}

class _QuickAddOption extends StatelessWidget {
  const _QuickAddOption({
    required this.heroTag,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final String heroTag;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: heroTag,
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
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
