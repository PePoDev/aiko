import 'package:flutter/material.dart';

import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';
import 'budget_form_screen.dart';

class BudgetOverviewScreen extends StatelessWidget {
  const BudgetOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Budget')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: [
          FinanceCard(
            title: 'Dining',
            icon: Icons.restaurant_outlined,
            accentColor: AikoColors.warningOrange,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('78% used', style: textTheme.titleSmall),
                    ),
                    Text('Keep 12 USD/day', style: textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: const LinearProgressIndicator(
                    value: 0.78,
                    color: AikoColors.warningOrange,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const FinanceCard(
            title: 'Aiko recommendation',
            icon: Icons.auto_awesome,
            accentColor: AikoColors.premiumPurple,
            child: Text('Keep dining under 12 USD per day to stay on track.'),
          ),
        ],
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
