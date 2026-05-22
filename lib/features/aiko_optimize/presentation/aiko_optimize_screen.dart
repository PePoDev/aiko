import 'package:flutter/material.dart';

import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';
import '../application/aiko_optimize_service.dart';

class AikoOptimizeScreen extends StatelessWidget {
  const AikoOptimizeScreen({super.key});

  static const _service = AikoOptimizeService();

  @override
  Widget build(BuildContext context) {
    final suggestions = _service.generate(
      budgetUtilizationPercent: 82,
      safeToSpendAmount: 74,
      upcomingBillsCount: 2,
      driftedAllocationsCount: 1,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Aiko Optimize')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FinanceCard(
              title: 'Optimization suggestions',
              icon: Icons.auto_awesome_outlined,
              accentColor: AikoColors.premiumPurple,
              child: Text('Ranked, explainable next steps.'),
            ),
            const SizedBox(height: 16),
            for (final suggestion in suggestions)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FinanceCard(
                  title: suggestion.title,
                  icon: Icons.tune_outlined,
                  accentColor: AikoColors.premiumPurple,
                  trailing: Text('${(suggestion.score * 100).round()}%'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(suggestion.reason),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () {},
                        child: Text(suggestion.actionLabel),
                      ),
                    ],
                  ),
                ),
              ),
            const FinanceCard(
              title: 'Prediction scenarios',
              icon: Icons.timeline_outlined,
              accentColor: AikoColors.analyticsTeal,
              child: Text(
                'Suggestions are ranked by confidence, recurring impact, and actionability.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
