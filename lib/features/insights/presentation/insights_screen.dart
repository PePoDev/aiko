import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../shared/widgets/screen_states.dart';
import '../../../theme/aiko_colors.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(aikoInsightsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: insightsAsync.when(
        loading: () => const AikoScreenState.loading(),
        error: (error, stack) => AikoScreenState.error(
          title: 'Insights are unavailable',
          message: 'Aiko could not load your insights right now.',
        ),
        data: (insights) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
          children: [
            if (insights.isEmpty)
              const AikoScreenState.empty(
                title: 'No insights yet',
                message:
                    'Aiko will show insights after enough real transaction data is available.',
              )
            else
              for (final insight in insights) ...[
                FinanceCard(
                  title: insight.title,
                  icon: Icons.insights,
                  accentColor: AikoColors.analyticsTeal,
                  child: Text(insight.description),
                ),
                const SizedBox(height: 16),
              ],
            FinanceCard(
              title: 'Aiko Review',
              icon: Icons.summarize_outlined,
              accentColor: AikoColors.premiumPurple,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'A calm monthly summary with estimates, trends, and next steps.',
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.go('/aiko-review'),
                    child: const Text('Open monthly review'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
