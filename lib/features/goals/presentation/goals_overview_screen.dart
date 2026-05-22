import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../shared/widgets/screen_states.dart';
import '../../../theme/aiko_colors.dart';

class GoalsOverviewScreen extends ConsumerWidget {
  const GoalsOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Goals')),
      body: goalsAsync.when(
        loading: () => const AikoScreenState.loading(),
        error: (error, stack) => AikoScreenState.error(
          title: 'Goals are unavailable',
          message: 'Aiko could not load your goals right now.',
        ),
        data: (goals) {
          if (goals.isEmpty) {
            return const AikoScreenState.empty(
              title: 'No goals yet',
              message: 'Create a goal to track your progress.',
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
            children: [
              for (final goal in goals) ...[
                FinanceCard(
                  title: goal.name,
                  icon: Icons.flag_outlined,
                  accentColor: AikoColors.successGreen,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${(goal.progress * 100).clamp(0, 100).toStringAsFixed(0)}% funded',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: goal.progress.clamp(0.0, 1.0),
                          color: AikoColors.successGreen,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${goal.currentAmount.format()} saved of ${goal.targetAmount.format()}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
          );
        },
      ),
    );
  }
}
