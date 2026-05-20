import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: [
          const FinanceCard(
            title: 'Food spending increased',
            icon: Icons.insights,
            accentColor: AikoColors.analyticsTeal,
            child: Text(
              'Food spending increased by 18%. Most of the increase came from weekend dining.',
            ),
          ),
          const SizedBox(height: 16),
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
    );
  }
}
