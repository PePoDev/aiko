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
            _FinancialPyramidCard(summary: summary),
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

class _FinancialPyramidCard extends StatelessWidget {
  const _FinancialPyramidCard({required this.summary});

  final DashboardSummary summary;

  static const List<_PyramidLevel> _levels = [
    _PyramidLevel(
      level: 5,
      title: 'Level 5 (Peak)',
      description:
          'Retire and build a retirement income strategy, fulfill your dreams, donate money, and plan your legacy.',
    ),
    _PyramidLevel(
      level: 4,
      title: 'Level 4',
      description:
          'Provide for aging parents, save for children\'s college, pay off your mortgage before retirement, maximize retirement savings, and consider long-term care insurance.',
    ),
    _PyramidLevel(
      level: 3,
      title: 'Level 3',
      description:
          'Buy a home, repay low-interest debt, provide for your children, and increase retirement savings.',
    ),
    _PyramidLevel(
      level: 2,
      title: 'Level 2',
      description:
          'Increase income, buy life and disability insurance, repay high-interest debt, and begin retirement savings.',
    ),
    _PyramidLevel(
      level: 1,
      title: 'Level 1 (Base)',
      description:
          'Earn enough income for monthly obligations, purchase health insurance, and establish an emergency fund.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final health = _PyramidHealth.fromSummary(summary);
    final currentLevel = _levels.firstWhere(
      (item) => item.level == health.level,
    );

    return FinanceCard(
      title: 'Financial Pyramid',
      icon: Icons.change_history,
      accentColor: AikoColors.analyticsTeal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Current health: ${currentLevel.title}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AikoColors.analyticsTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${health.scorePercent}% fit',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AikoColors.analyticsTeal,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Build the base first, then climb tier by tier.'),
          const SizedBox(height: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < _levels.length; i++)
                _PyramidTier3D(
                  level: _levels[i],
                  isActive: _levels[i].level <= health.level,
                  widthFactor: 0.56 + ((_levels.length - 1 - i) * 0.11),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            currentLevel.description,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _PyramidTier3D extends StatelessWidget {
  const _PyramidTier3D({
    required this.level,
    required this.isActive,
    required this.widthFactor,
  });

  final _PyramidLevel level;
  final bool isActive;
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    final activeColor =
        Color.lerp(
          AikoColors.softBlue,
          AikoColors.deepBlue,
          (level.level - 1) / 4,
        ) ??
        AikoColors.primaryBlue;
    final faceColor = isActive
        ? activeColor.withValues(alpha: 0.94)
        : AikoColors.border;
    final shadowColor = isActive
        ? activeColor.withValues(alpha: 0.45)
        : AikoColors.mutedText.withValues(alpha: 0.2);
    final topColor = isActive
        ? activeColor.withValues(alpha: 0.72)
        : AikoColors.borderSubtle;

    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: SizedBox(
          height: 44,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 8,
                right: 0,
                top: 5,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: shadowColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 8,
                top: 0,
                bottom: 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [faceColor, topColor],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isActive
                          ? Colors.white.withValues(alpha: 0.18)
                          : AikoColors.border,
                    ),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        level.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: isActive ? Colors.white : AikoColors.mutedText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PyramidLevel {
  const _PyramidLevel({
    required this.level,
    required this.title,
    required this.description,
  });

  final int level;
  final String title;
  final String description;
}

class _PyramidHealth {
  const _PyramidHealth({required this.level, required this.scorePercent});

  final int level;
  final int scorePercent;

  static _PyramidHealth fromSummary(DashboardSummary summary) {
    final income = summary.monthlyIncome.amount.toDouble();
    final spending = summary.monthlySpending.amount.toDouble();
    final safe = summary.safeToSpend.amount.toDouble();
    final totalCash = summary.totalCash.amount.toDouble();

    final incomeCoverage = income <= 0 ? 0.0 : (income - spending) / income;
    final safeRatio = income <= 0 ? 0.0 : safe / income;
    final cashBuffer = spending <= 0 ? 0.0 : totalCash / spending;
    final paceScore = summary.paceStatus.isFast ? 0.15 : 1.0;

    final normalized =
        (incomeCoverage.clamp(0.0, 1.0) * 0.35) +
        (safeRatio.clamp(0.0, 1.0) * 0.25) +
        (cashBuffer.clamp(0.0, 1.0) * 0.25) +
        (paceScore * 0.15);

    final scorePercent = (normalized * 100).round().clamp(0, 100);
    final level = ((normalized * 5).ceil()).clamp(1, 5);

    return _PyramidHealth(level: level, scorePercent: scorePercent);
  }
}
