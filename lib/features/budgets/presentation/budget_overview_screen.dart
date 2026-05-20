import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../shared/widgets/screen_states.dart';
import '../../../theme/aiko_colors.dart';
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
                  icon: Icons.restaurant_outlined,
                  accentColor: AikoColors.warningOrange,
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
                          Text('Monthly limit', style: textTheme.bodySmall),
                        ],
                      ),
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
