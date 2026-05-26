import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../shared/widgets/screen_states.dart';
import '../../../theme/aiko_colors.dart';
import '../domain/budget.dart';
import 'budget_form_screen.dart';

class BudgetOverviewScreen extends ConsumerWidget {
  const BudgetOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final budgetsAsync = ref.watch(budgetsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Budget')),
      body: budgetsAsync.when(
        loading: () => const AikoScreenState.loading(),
        error: (error, stack) => AikoScreenState.error(
          title: 'Budgets are unavailable',
          message: 'Aiko could not load your budgets right now.',
        ),
        data: (budgets) {
          if (budgets.isEmpty) {
            return const AikoScreenState.empty(
              title: 'No budgets yet',
              message: 'Add a monthly budget to start tracking your pace.',
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
            children: [
              for (final budget in budgets) ...[
                FinanceCard(
                  title: budget.name,
                  icon: budget.isDailySpending
                      ? Icons.today_outlined
                      : Icons.restaurant_outlined,
                  accentColor: AikoColors.warningOrange,
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AikoColors.mutedText,
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _BudgetDetailScreen(budget: budget),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              budget.amount.format(),
                              style: textTheme.titleSmall,
                            ),
                          ),
                          Text(
                            budget.isDailySpending
                                ? 'Daily limit'
                                : 'Monthly limit',
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                      if (budget.isDailySpending) ...[
                        const SizedBox(height: 6),
                        Text(
                          _includedCategoriesLabel(budget),
                          style: textTheme.bodySmall?.copyWith(
                            color: AikoColors.mutedText,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: const LinearProgressIndicator(
                          value: 0.0,
                          color: AikoColors.warningOrange,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const FinanceCard(
                title: 'Aiko recommendation',
                icon: Icons.auto_awesome,
                accentColor: AikoColors.premiumPurple,
                child: Text(
                  'Keep each category under its daily pace to stay on track.',
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const BudgetFormScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Budget'),
      ),
    );
  }
}

class _BudgetDetailScreen extends ConsumerStatefulWidget {
  const _BudgetDetailScreen({required this.budget});

  final Budget budget;

  @override
  ConsumerState<_BudgetDetailScreen> createState() =>
      _BudgetDetailScreenState();
}

class _BudgetDetailScreenState extends ConsumerState<_BudgetDetailScreen> {
  late Budget _budget;

  @override
  void initState() {
    super.initState();
    _budget = widget.budget;
  }

  Future<void> _editBudget() async {
    final updated = await Navigator.of(context).push<Budget>(
      MaterialPageRoute(
        builder: (_) => BudgetFormScreen(initialBudget: _budget),
      ),
    );

    if (updated == null || !mounted) {
      return;
    }
    setState(() => _budget = updated);
  }

  Future<void> _deleteBudget() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete budget?'),
        content: Text(
          'Are you sure you want to delete "${_budget.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await ref.read(budgetsProvider.notifier).deleteBudget(_budget.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Budget "${_budget.name}" deleted.')),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to delete budget right now.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget details'),
        actions: [
          if (_budget.canDelete)
            IconButton(
              tooltip: 'Delete budget',
              onPressed: _deleteBudget,
              icon: const Icon(Icons.delete_outline),
            ),
          IconButton(
            tooltip: 'Edit budget',
            onPressed: _editBudget,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          FinanceCard(
            title: _budget.name,
            icon: _budget.isDailySpending
                ? Icons.today_outlined
                : Icons.restaurant_outlined,
            accentColor: AikoColors.warningOrange,
            prominent: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AmountText(_budget.amount.format()),
                const SizedBox(height: 16),
                _BudgetDetailRow(
                  label: 'Period',
                  value: _periodLabel(_budget.period),
                ),
                if (_budget.isDailySpending) ...[
                  const Divider(),
                  _BudgetDetailRow(
                    label: 'Categories',
                    value: _includedCategoriesLabel(_budget),
                  ),
                ],
                const Divider(),
                _BudgetDetailRow(
                  label: 'Start',
                  value: _dateLabel(_budget.periodStart),
                ),
                const Divider(),
                _BudgetDetailRow(
                  label: 'End',
                  value: _dateLabel(_budget.periodEnd),
                ),
                const Divider(),
                _BudgetDetailRow(
                  label: 'Status',
                  value: _statusLabel(_budget.status),
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetDetailRow extends StatelessWidget {
  const _BudgetDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AikoColors.mutedText),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

String _dateLabel(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String _periodLabel(BudgetPeriod period) {
  return period.name[0].toUpperCase() + period.name.substring(1);
}

String _statusLabel(BudgetStatus status) {
  return status.name[0].toUpperCase() + status.name.substring(1);
}

String _includedCategoriesLabel(Budget budget) {
  final count = budget.includedCategoryIds.length;
  if (count == 0) {
    return 'No categories selected';
  }
  if (count == 1) {
    return '1 category included';
  }
  return '$count categories included';
}
